import AppKit
import ApplicationServices

enum Accessibility {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestPrompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Distributed notification posted whenever any app's accessibility trust changes.
    static let trustChangedNotification = Notification.Name("com.apple.accessibility.api")
}
