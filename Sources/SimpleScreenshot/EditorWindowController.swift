import AppKit

@MainActor
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    private let canvas: AnnotationCanvas
    private var didSave = false
    private static var active: [EditorWindowController] = []

    static func present(image: NSImage) {
        let controller = EditorWindowController(image: image)
        active.append(controller)
        controller.showWindow(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        controller.window?.makeKeyAndOrderFront(nil)
        controller.window?.makeFirstResponder(controller.canvas)
    }

    private init(image: NSImage) {
        canvas = AnnotationCanvas(image: image)
        let size = Self.fittedWindowSize(for: image.size)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Simple Screenshot — Escで保存"
        window.minSize = NSSize(width: 640, height: 420)
        super.init(window: window)
        window.delegate = self
        window.contentView = makeLayout()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func makeLayout() -> NSView {
        let root = NSView()
        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.spacing = 8
        toolbar.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        let tools: [(String, String, AnnotationTool)] = [("arrow.up.left.and.arrow.down.right", "選択 (V)", .select), ("textformat", "テキスト (T)", .text), ("arrow.up.right", "矢印 (A)", .arrow), ("rectangle", "四角 (R)", .rectangle)]
        for (icon, tip, tool) in tools {
            let button = NSButton(image: NSImage(systemSymbolName: icon, accessibilityDescription: tip)!, target: self, action: #selector(selectTool(_:)))
            button.toolTip = tip; button.tag = tool.rawValue; button.bezelStyle = .texturedRounded
            toolbar.addArrangedSubview(button)
        }
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal); toolbar.addArrangedSubview(spacer)
        let help = NSTextField(labelWithString: "ドラッグで描画  •  ⌘Z 取り消し  •  Esc 保存＋コピー")
        help.textColor = .secondaryLabelColor; toolbar.addArrangedSubview(help)
        let save = NSButton(title: "保存", target: self, action: #selector(saveAndClose)); save.keyEquivalent = "\r"; toolbar.addArrangedSubview(save)

        toolbar.translatesAutoresizingMaskIntoConstraints = false; canvas.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(toolbar); root.addSubview(canvas)
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: root.topAnchor), toolbar.leadingAnchor.constraint(equalTo: root.leadingAnchor), toolbar.trailingAnchor.constraint(equalTo: root.trailingAnchor), toolbar.heightAnchor.constraint(equalToConstant: 48),
            canvas.topAnchor.constraint(equalTo: toolbar.bottomAnchor), canvas.leadingAnchor.constraint(equalTo: root.leadingAnchor), canvas.trailingAnchor.constraint(equalTo: root.trailingAnchor), canvas.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
        return root
    }

    @objc private func selectTool(_ sender: NSButton) { canvas.tool = AnnotationTool(rawValue: sender.tag) ?? .select }
    @objc func saveAndClose() { finish() }

    func windowShouldClose(_ sender: NSWindow) -> Bool { finish(); return false }

    private func finish() {
        guard !didSave else { return }
        didSave = true
        do {
            let image = canvas.renderedImage()
            _ = try Storage.saveJPEG(image)
            Storage.copyToPasteboard(image)
        } catch {
            NSAlert(error: error).runModal()
        }
        window?.orderOut(nil)
        Self.active.removeAll { $0 === self }
        if Self.active.isEmpty { NSApp.setActivationPolicy(.accessory) }
    }

    private static func fittedWindowSize(for image: NSSize) -> NSSize {
        let maxSize = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1200, height: 800)
        let scale = min(1, (maxSize.width - 80) / image.width, (maxSize.height - 100) / image.height)
        return NSSize(width: max(640, image.width * scale), height: max(420, image.height * scale + 48))
    }
}

private enum Annotation {
    case arrow(CGPoint, CGPoint)
    case rectangle(CGRect)
    case text(String, CGPoint)
}

final class AnnotationCanvas: NSView {
    let image: NSImage
    var tool: AnnotationTool = .arrow { didSet { updateCursor() } }
    private var annotations: [Annotation] = []
    private var dragStart: CGPoint?
    private var dragEnd: CGPoint?
    private let ink = NSColor.systemRed

    init(image: NSImage) { self.image = image; super.init(frame: .zero); wantsLayer = true; layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor }
    required init?(coder: NSCoder) { fatalError() }
    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let imageRect = fittedImageRect
        image.draw(in: imageRect, from: .zero, operation: .copy, fraction: 1)
        for annotation in annotations { draw(annotation, in: imageRect) }
        if let start = dragStart, let end = dragEnd {
            if tool == .arrow { draw(.arrow(start, end), in: imageRect) }
            if tool == .rectangle { draw(.rectangle(rect(from: start, to: end)), in: imageRect) }
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = imagePoint(event)
        guard imageBounds.contains(point) else { return }
        if tool == .text { requestText(at: point); return }
        if tool == .arrow || tool == .rectangle { dragStart = point; dragEnd = point }
    }
    override func mouseDragged(with event: NSEvent) { guard dragStart != nil else { return }; dragEnd = imagePoint(event); needsDisplay = true }
    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart, let end = dragEnd else { return }
        if tool == .arrow { annotations.append(.arrow(start, end)) }
        if tool == .rectangle { annotations.append(.rectangle(rect(from: start, to: end))) }
        dragStart = nil; dragEnd = nil; needsDisplay = true
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { (window?.windowController as? EditorWindowController)?.saveAndClose(); return }
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "z" { _ = annotations.popLast(); needsDisplay = true; return }
        switch event.charactersIgnoringModifiers?.lowercased() { case "v": tool = .select; case "t": tool = .text; case "a": tool = .arrow; case "r": tool = .rectangle; default: super.keyDown(with: event) }
    }

    func renderedImage() -> NSImage {
        let output = NSImage(size: image.size)
        output.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: image.size), from: .zero, operation: .copy, fraction: 1)
        for annotation in annotations { draw(annotation, in: NSRect(origin: .zero, size: image.size)) }
        output.unlockFocus()
        return output
    }

    private func requestText(at point: CGPoint) {
        let alert = NSAlert(); alert.messageText = "テキストを追加"; alert.addButton(withTitle: "追加"); alert.addButton(withTitle: "キャンセル")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 26)); alert.accessoryView = field
        if alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty { annotations.append(.text(field.stringValue, point)); needsDisplay = true }
    }

    private func draw(_ annotation: Annotation, in target: CGRect) {
        let sx = target.width / image.size.width, sy = target.height / image.size.height
        func p(_ value: CGPoint) -> CGPoint { CGPoint(x: target.minX + value.x*sx, y: target.minY + value.y*sy) }
        ink.setStroke(); ink.setFill()
        switch annotation {
        case .rectangle(let value):
            let r = CGRect(x: target.minX+value.minX*sx, y: target.minY+value.minY*sy, width: value.width*sx, height: value.height*sy)
            let path = NSBezierPath(roundedRect: r, xRadius: 3, yRadius: 3); path.lineWidth = max(2, 4*sx); path.stroke()
        case .arrow(let from, let to):
            let a = p(from), b = p(to), path = NSBezierPath(); path.move(to: a); path.line(to: b); path.lineWidth = max(2, 4*sx); path.stroke()
            let angle = atan2(b.y-a.y, b.x-a.x), length = max(12, 18*sx)
            let head = NSBezierPath()
            head.move(to: b)
            head.line(to: CGPoint(x: b.x - length * cos(angle - 0.5), y: b.y - length * sin(angle - 0.5)))
            head.line(to: CGPoint(x: b.x - length * cos(angle + 0.5), y: b.y - length * sin(angle + 0.5)))
            head.close()
            head.fill()
        case .text(let text, let at):
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: max(16, 24*sx), weight: .semibold), .foregroundColor: ink, .strokeColor: NSColor.white, .strokeWidth: -2]
            text.draw(at: p(at), withAttributes: attributes)
        }
    }

    private var fittedImageRect: CGRect {
        let scale = min(bounds.width/image.size.width, bounds.height/image.size.height)
        let size = CGSize(width: image.size.width*scale, height: image.size.height*scale)
        return CGRect(x: bounds.midX-size.width/2, y: bounds.midY-size.height/2, width: size.width, height: size.height)
    }
    private var imageBounds: CGRect { CGRect(origin: .zero, size: image.size) }
    private func imagePoint(_ event: NSEvent) -> CGPoint { let p = convert(event.locationInWindow, from: nil), r = fittedImageRect; return CGPoint(x: (p.x-r.minX)*image.size.width/r.width, y: (p.y-r.minY)*image.size.height/r.height) }
    private func rect(from a: CGPoint, to b: CGPoint) -> CGRect { CGRect(x: min(a.x,b.x), y: min(a.y,b.y), width: abs(a.x-b.x), height: abs(a.y-b.y)) }
    private func updateCursor() { addCursorRect(bounds, cursor: tool == .select ? .arrow : .crosshair) }
}
