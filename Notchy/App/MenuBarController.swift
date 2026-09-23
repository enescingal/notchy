import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let noNotchItem = NSMenuItem(title: "Çentikli ekran bulunamadı", action: nil, keyEquivalent: "")
    private let onSettings: () -> Void

    init(onSettings: @escaping () -> Void) {
        self.onSettings = onSettings
        super.init()
        let icon = NSImage(named: "MenuBarIcon")
        icon?.isTemplate = true
        icon?.accessibilityDescription = "Notchy"
        statusItem.button?.image = icon
        let menu = NSMenu()
        noNotchItem.isEnabled = false
        noNotchItem.isHidden = true
        menu.addItem(noNotchItem)
        menu.addItem(makeItem("Ayarlar…", #selector(openSettings), key: ","))
        menu.addItem(makeItem("Notchy Hakkında", #selector(openAbout), key: ""))
        menu.addItem(.separator())
        menu.addItem(makeItem("Çıkış", #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    func setHasNotch(_ hasNotch: Bool) {
        noNotchItem.isHidden = hasNotch
    }

    private func makeItem(_ title: String, _ action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func openSettings() { onSettings() }

    @objc private func openAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
