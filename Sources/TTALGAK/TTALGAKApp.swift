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
        item.button?.image = NSImage(systemSymbolName: "figure.run", accessibilityDescription: "TTALGAK")
        item.menu = menu()
        statusItem = item
        overlayController.show()
    }

    private func menu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Hide TTALGAK", action: #selector(toggleOverlay), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit TTALGAK", action: #selector(quit), keyEquivalent: "q")
        return menu
    }

    @objc private func toggleOverlay() {
        overlayController.toggle()
        statusItem?.menu?.item(at: 0)?.title = overlayController.isVisible ? "Hide TTALGAK" : "Show TTALGAK"
    }

    @objc private func quit() { NSApplication.shared.terminate(nil) }
}
