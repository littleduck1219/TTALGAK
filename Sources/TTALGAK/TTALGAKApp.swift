import AppKit

@main
enum TTALGAKApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let overlayController = OverlayController()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "TTALGAK")
        item.menu = menu()
        statusItem = item
        overlayController.show()
    }

    private func menu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Hide boxes", action: #selector(togglePlaceholders), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit TTALGAK", action: #selector(quit), keyEquivalent: "q")
        return menu
    }

    @objc private func togglePlaceholders() {
        overlayController.toggle()
        statusItem?.menu?.item(at: 0)?.title = overlayController.isVisible ? "Hide boxes" : "Show boxes"
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
