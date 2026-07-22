import AppKit
import ScreenCaptureKit

@MainActor
final class CaptureCoordinator {
    private var recorder: VideoRecorder?

    func perform(_ action: CaptureAction) async {
        do {
            switch action {
            case .screenImage, .areaImage, .windowImage:
                let image = try await captureImage(action)
                EditorWindowController.present(image: image)
            case .screenVideo, .areaVideo, .windowVideo:
                try await startRecording(action)
            }
        } catch CaptureError.cancelled {
            return
        } catch {
            show(error)
        }
    }

    func stopRecording() async {
        guard let recorder else { return }
        self.recorder = nil
        do {
            let url = try await recorder.stop()
            NSSound(named: "Glass")?.play()
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch { show(error) }
    }

    private func captureImage(_ action: CaptureAction) async throws -> NSImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = mainDisplay(in: content) ?? content.displays.first else { throw CaptureError.noDisplay }

        let selection = try await target(for: action, content: content, display: display)
        let captureDisplay = displayFor(selection, in: content) ?? display
        let filter: SCContentFilter
        let config = SCStreamConfiguration()
        config.showsCursor = false
        config.captureResolution = .best

        switch selection {
        case .display:
            filter = SCContentFilter(display: captureDisplay, excludingWindows: [])
            config.width = captureDisplay.width; config.height = captureDisplay.height
        case .area(let rect):
            filter = SCContentFilter(display: captureDisplay, excludingWindows: [])
            let local = CGRect(x: rect.minX - captureDisplay.frame.minX, y: rect.minY - captureDisplay.frame.minY, width: rect.width, height: rect.height)
            config.sourceRect = local
            config.width = Int(rect.width * 2); config.height = Int(rect.height * 2)
        case .window(let window):
            filter = SCContentFilter(desktopIndependentWindow: window)
            config.width = Int(window.frame.width * 2); config.height = Int(window.frame.height * 2)
        }

        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private func startRecording(_ action: CaptureAction) async throws {
        if recorder != nil { return }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = mainDisplay(in: content) ?? content.displays.first else { throw CaptureError.noDisplay }
        let selection = try await target(for: action, content: content, display: display)
        recorder = try await VideoRecorder.start(selection: selection, display: displayFor(selection, in: content) ?? display)
        NSSound(named: "Tink")?.play()
    }

    enum Target { case display, area(CGRect), window(SCWindow) }

    private func target(for action: CaptureAction, content: SCShareableContent, display: SCDisplay) async throws -> Target {
        switch action {
        case .screenImage, .screenVideo: return .display
        case .areaImage, .areaVideo:
            guard let rect = await SelectionOverlay.select(.area) else { throw CaptureError.cancelled }
            return .area(rect)
        case .windowImage, .windowVideo:
            let windows = content.windows.filter { $0.isOnScreen && $0.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier && $0.frame.width > 80 }
            guard let rect = await SelectionOverlay.select(.window(windows)),
                  let window = windows.min(by: { frameDistance($0.frame, rect) < frameDistance($1.frame, rect) }) else { throw CaptureError.cancelled }
            return .window(window)
        }
    }

    private func frameDistance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        abs(a.minX-b.minX) + abs(a.minY-b.minY) + abs(a.width-b.width) + abs(a.height-b.height)
    }

    private func mainDisplay(in content: SCShareableContent) -> SCDisplay? {
        guard let number = NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        return content.displays.first { $0.displayID == CGDirectDisplayID(number.uint32Value) }
    }

    private func displayFor(_ target: Target, in content: SCShareableContent) -> SCDisplay? {
        guard case .area(let rect) = target else { return nil }
        return content.displays.max { lhs, rhs in
            lhs.frame.intersection(rect).width * lhs.frame.intersection(rect).height < rhs.frame.intersection(rect).width * rhs.frame.intersection(rect).height
        }
    }

    private func show(_ error: Error) {
        let alert = NSAlert(error: error); alert.runModal()
    }
}
