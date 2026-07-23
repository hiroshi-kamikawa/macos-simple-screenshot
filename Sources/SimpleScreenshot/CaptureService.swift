import AppKit
import ScreenCaptureKit

@MainActor
final class CaptureCoordinator {
    private enum RecordingState {
        case idle
        case starting(UUID)
        case active(VideoRecorder)
    }

    private var recordingState = RecordingState.idle

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
        switch recordingState {
        case .idle:
            return
        case .starting:
            recordingState = .idle
            return
        case .active(let recorder):
            recordingState = .idle
            await finishRecording(recorder)
        }
    }

    private func finishRecording(_ recorder: VideoRecorder) async {
        do {
            let url = try await recorder.stop()
            NSSound(named: "Glass")?.play()
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch { show(error) }
    }

    private func captureImage(_ action: CaptureAction) async throws -> NSImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = mainDisplay(in: content) ?? content.displays.first else { throw CaptureError.noDisplay }

        var selection = try await target(for: action, content: content, display: display)
        var captureContent = content
        if case .window = selection {
            captureContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            selection = try revalidateWindow(selection, in: captureContent)
        }
        guard let captureDisplay = displayFor(selection, in: captureContent)
            ?? mainDisplay(in: captureContent)
            ?? captureContent.displays.first else {
            throw CaptureError.noDisplay
        }
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
        guard case .idle = recordingState else { return }
        let startID = UUID()
        recordingState = .starting(startID)

        do {
            var content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let initialDisplay = mainDisplay(in: content) ?? content.displays.first else { throw CaptureError.noDisplay }
            var selection = try await target(for: action, content: content, display: initialDisplay)
            if case .window = selection {
                content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                selection = try revalidateWindow(selection, in: content)
            }
            guard let display = displayFor(selection, in: content) ?? mainDisplay(in: content) ?? content.displays.first else {
                throw CaptureError.noDisplay
            }
            guard case .starting(let currentStartID) = recordingState,
                  currentStartID == startID else {
                throw CaptureError.cancelled
            }
            let recorder = try await VideoRecorder.start(selection: selection, display: display)
            guard case .starting(let currentStartID) = recordingState,
                  currentStartID == startID else {
                _ = try? await recorder.stop()
                throw CaptureError.cancelled
            }
            recordingState = .active(recorder)
        } catch {
            if case .starting(let currentStartID) = recordingState,
               currentStartID == startID {
                recordingState = .idle
            }
            throw error
        }
        NSSound(named: "Tink")?.play()
    }

    enum Target { case display, area(CGRect), window(SCWindow) }

    private func target(for action: CaptureAction, content: SCShareableContent, display: SCDisplay) async throws -> Target {
        switch action {
        case .screenImage, .screenVideo: return .display
        case .areaImage, .areaVideo:
            guard case .area(let rect)? = await SelectionOverlay.select(.area) else { throw CaptureError.cancelled }
            return .area(rect)
        case .windowImage, .windowVideo:
            let windows = content.windows.filter { $0.isOnScreen && $0.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier && $0.frame.width > 80 }
            guard case .window(let window)? = await SelectionOverlay.select(.window(windows)) else { throw CaptureError.cancelled }
            return .window(window)
        }
    }

    private func revalidateWindow(_ target: Target, in content: SCShareableContent) throws -> Target {
        guard case .window(let selectedWindow) = target,
              let currentWindow = content.windows.first(where: {
                  $0.windowID == selectedWindow.windowID && $0.isOnScreen
              }) else {
            throw CaptureError.cancelled
        }
        return .window(currentWindow)
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
