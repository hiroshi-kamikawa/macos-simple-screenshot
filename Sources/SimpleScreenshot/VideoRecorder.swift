import AVFoundation
import ScreenCaptureKit

final class VideoRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private let stream: SCStream
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let queue = DispatchQueue(label: "jp.lightshot.recording")
    private var started = false

    private init(stream: SCStream, writer: AVAssetWriter, input: AVAssetWriterInput) {
        self.stream = stream; self.writer = writer; self.input = input
    }

    static func start(selection: CaptureCoordinator.Target, display: SCDisplay) async throws -> VideoRecorder {
        let filter: SCContentFilter
        let config = SCStreamConfiguration()
        let frameRate = 24
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        config.queueDepth = 5
        config.showsCursor = true
        config.pixelFormat = kCVPixelFormatType_32BGRA

        let sourceSize: CGSize
        switch selection {
        case .display:
            filter = SCContentFilter(display: display, excludingWindows: [])
            sourceSize = CGSize(width: display.width, height: display.height)
        case .area(let rect):
            filter = SCContentFilter(display: display, excludingWindows: [])
            config.sourceRect = CGRect(x: rect.minX-display.frame.minX, y: rect.minY-display.frame.minY, width: rect.width, height: rect.height)
            sourceSize = rect.size
        case .window(let window):
            filter = SCContentFilter(desktopIndependentWindow: window)
            sourceSize = window.frame.size
        }

        let scale = min(1, 1920 / max(sourceSize.width, sourceSize.height))
        let width = max(2, Int(sourceSize.width * scale) / 2 * 2)
        let height = max(2, Int(sourceSize.height * scale) / 2 * 2)
        config.width = width; config.height = height

        let url = Storage.videoURL()
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        // Screen recordings compress well at a lower, resolution-aware bitrate.
        // HEVC preserves text and UI edges more efficiently than H.264.
        let bitsPerPixel = 0.45
        let averageBitRate = min(900_000, max(220_000, Int(Double(width * height) * bitsPerPixel)))
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: averageBitRate,
                AVVideoExpectedSourceFrameRateKey: frameRate,
                AVVideoMaxKeyFrameIntervalKey: frameRate * 5
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { throw CaptureError.exportFailed }
        writer.add(input)

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        let recorder = VideoRecorder(stream: stream, writer: writer, input: input)
        try stream.addStreamOutput(recorder, type: .screen, sampleHandlerQueue: recorder.queue)
        try await stream.startCapture()
        return recorder
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid, CMSampleBufferDataIsReady(sampleBuffer) else { return }
        if !started {
            writer.startWriting()
            writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
            started = true
        }
        if input.isReadyForMoreMediaData { input.append(sampleBuffer) }
    }

    func stop() async throws -> URL {
        try await stream.stopCapture()
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? CaptureError.exportFailed }
        return writer.outputURL
    }
}
