import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let coordinator = CaptureCoordinator()
    private var hotKeys: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "Simple Screenshot")
        statusItem.menu = makeMenu()

        hotKeys = HotKeyManager { [weak self] action in
            Task { @MainActor in await self?.coordinator.perform(action) }
        }
        hotKeys?.registerDefaults()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        add("画面を撮影", key: "1", modifiers: [.command, .shift], action: .screenImage, to: menu)
        add("領域を撮影", key: "2", modifiers: [.command, .shift], action: .areaImage, to: menu)
        add("ウィンドウを撮影", key: "3", modifiers: [.command, .shift], action: .windowImage, to: menu)
        menu.addItem(.separator())
        add("画面を録画", key: "4", modifiers: [.command, .shift], action: .screenVideo, to: menu)
        add("領域を録画", key: "5", modifiers: [.command, .shift], action: .areaVideo, to: menu)
        add("ウィンドウを録画", key: "6", modifiers: [.command, .shift], action: .windowVideo, to: menu)
        let stop = NSMenuItem(title: "録画を停止", action: #selector(stopRecording), keyEquivalent: ".")
        stop.keyEquivalentModifierMask = [.command, .shift]
        stop.target = self
        menu.addItem(stop)
        menu.addItem(.separator())
        let folder = NSMenuItem(title: "保存先を開く", action: #selector(openFolder), keyEquivalent: "")
        folder.target = self
        menu.addItem(folder)
        let quit = NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    private func add(_ title: String, key: String, modifiers: NSEvent.ModifierFlags, action: CaptureAction, to menu: NSMenu) {
        let item = ActionMenuItem(title: title, action: #selector(runAction(_:)), keyEquivalent: key)
        item.captureAction = action
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        menu.addItem(item)
    }

    @objc private func runAction(_ sender: ActionMenuItem) {
        guard let action = sender.captureAction else { return }
        Task { @MainActor in await coordinator.perform(action) }
    }

    @objc private func stopRecording() { Task { @MainActor in await coordinator.stopRecording() } }
    @objc private func openFolder() { NSWorkspace.shared.open(Storage.outputDirectory) }
}

private final class ActionMenuItem: NSMenuItem {
    var captureAction: CaptureAction?
}
