import AppKit
import AVFoundation

enum Storage {
    static var outputDirectory: URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let directory = downloads.appendingPathComponent("Screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func imageURL() -> URL { outputDirectory.appendingPathComponent("Screenshot-\(timestamp()).jpg") }
    static func videoURL() -> URL { outputDirectory.appendingPathComponent("Recording-\(timestamp()).mp4") }

    static func saveJPEG(_ image: NSImage, quality: CGFloat = 0.68) throws -> URL {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            throw CaptureError.exportFailed
        }
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
