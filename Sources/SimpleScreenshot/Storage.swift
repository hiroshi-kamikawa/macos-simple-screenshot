import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

enum Storage {
    static var outputDirectory: URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let directory = downloads.appendingPathComponent("Screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func imageURL() -> URL { outputDirectory.appendingPathComponent("Screenshot-\(timestamp()).heic") }
    static func videoURL() -> URL { outputDirectory.appendingPathComponent("Recording-\(timestamp()).mp4") }

    static func saveImage(_ image: NSImage, quality: CGFloat = 0.60) throws -> URL {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let cgImage = bitmap.cgImage else {
            throw CaptureError.exportFailed
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else { throw CaptureError.exportFailed }
        let properties = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, properties)
        guard CGImageDestinationFinalize(destination) else { throw CaptureError.exportFailed }

        let url = imageURL()
        try data.write(to: url, options: .atomic)
        return url
    }

    static func copyToPasteboard(_ image: NSImage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
}
