import AppKit
import SwiftUI

/// Shows a single reusable window for a SwiftUI view (accessory apps have no scene windows).
@MainActor
final class WindowPresenter {
    private var window: NSWindow?

    func show<V: View>(title: String, @ViewBuilder content: () -> V) {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
            window.title = title
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
        window = nil
    }
}
