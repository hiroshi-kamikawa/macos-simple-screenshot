import AppKit
import ScreenCaptureKit

@MainActor
final class SelectionOverlay: NSWindowController {
    enum Mode { case area, window([SCWindow]) }
    private var continuation: CheckedContinuation<CGRect?, Never>?

    static func select(_ mode: Mode) async -> CGRect? {
        let controller = SelectionOverlay(mode: mode)
        return await withCheckedContinuation { continuation in
            controller.continuation = continuation
            OverlayLifetime.shared.retain(controller)
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            controller.window?.makeKeyAndOrderFront(nil)
        }
    }

    private init(mode: Mode) {
        let union = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        let window = NSWindow(contentRect: union, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        super.init(window: window)
        let view = SelectionView(frame: CGRect(origin: .zero, size: union.size), mode: mode)
        view.onFinish = { [weak self] rect in self?.finish(rect) }
        window.contentView = view
    }

    required init?(coder: NSCoder) { fatalError() }

    private func finish(_ rect: CGRect?) {
        window?.orderOut(nil)
        let pending = continuation
        continuation = nil
        OverlayLifetime.shared.release(self)
        // Give WindowServer one frame to remove the dimming overlay before capture.
        DispatchQueue.main.async { pending?.resume(returning: rect) }
    }
}

@MainActor private final class OverlayLifetime {
    static let shared = OverlayLifetime()
    private var controllers: [NSWindowController] = []
    func retain(_ value: NSWindowController) { controllers.append(value) }
    func release(_ value: NSWindowController) { controllers.removeAll { $0 === value } }
}

private final class SelectionView: NSView {
    let mode: SelectionOverlay.Mode
    var onFinish: ((CGRect?) -> Void)?
    private var start: CGPoint?
    private var selection = CGRect.zero { didSet { needsDisplay = true } }
    private var highlighted: SCWindow?

    init(frame: CGRect, mode: SelectionOverlay.Mode) { self.mode = mode; super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError() }
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill(); bounds.fill()
        let rect = highlighted.map(localRect(for:)) ?? selection
        if !rect.isEmpty {
            NSGraphicsContext.current?.saveGraphicsState()
            NSBezierPath(rect: rect).addClip()
            NSColor.clear.setFill(); rect.fill(using: .copy)
            NSColor.systemBlue.setStroke()
            let border = NSBezierPath(rect: rect); border.lineWidth = 2; border.stroke()
            NSGraphicsContext.current?.restoreGraphicsState()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        switch mode {
        case .area: start = point; selection = CGRect(origin: point, size: .zero)
        case .window: updateWindow(at: point)
        }
    }
    override func mouseDragged(with event: NSEvent) {
        guard case .area = mode, let start else { return }
        let point = convert(event.locationInWindow, from: nil)
        selection = CGRect(x: min(start.x, point.x), y: min(start.y, point.y), width: abs(point.x-start.x), height: abs(point.y-start.y))
    }
    override func mouseMoved(with event: NSEvent) { if case .window = mode { updateWindow(at: convert(event.locationInWindow, from: nil)) } }
    override func mouseUp(with event: NSEvent) {
        switch mode {
        case .area: onFinish?(selection.width > 4 && selection.height > 4 ? globalRect(selection) : nil)
        case .window: onFinish?(highlighted?.frame)
        }
    }
    override func keyDown(with event: NSEvent) { if event.keyCode == 53 { onFinish?(nil) } }

    private func updateWindow(at local: CGPoint) {
        guard case .window(let windows) = mode else { return }
        let cocoa = CGPoint(x: local.x + (window?.frame.minX ?? 0), y: local.y + (window?.frame.minY ?? 0))
        let global = CGPoint(x: cocoa.x, y: primaryTop - cocoa.y)
        highlighted = windows.first { $0.frame.contains(global) }
        needsDisplay = true
    }
    private func localRect(for window: SCWindow) -> CGRect {
        let frame = window.frame
        let cocoaY = primaryTop - frame.maxY
        return CGRect(x: frame.minX - (self.window?.frame.minX ?? 0), y: cocoaY - (self.window?.frame.minY ?? 0), width: frame.width, height: frame.height)
    }
    private func globalRect(_ local: CGRect) -> CGRect {
        let cocoa = local.offsetBy(dx: window?.frame.minX ?? 0, dy: window?.frame.minY ?? 0)
        return CGRect(x: cocoa.minX, y: primaryTop - cocoa.maxY, width: cocoa.width, height: cocoa.height)
    }
    private var primaryTop: CGFloat { NSScreen.screens.first?.frame.maxY ?? 0 }
}
