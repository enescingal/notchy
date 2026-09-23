import OSLog

enum Log {
    static let subsystem = "com.notchy"
    static let app = Logger(subsystem: subsystem, category: "App")
    static let notch = Logger(subsystem: subsystem, category: "Notch")
    static let media = Logger(subsystem: subsystem, category: "Media")
    static let hud = Logger(subsystem: subsystem, category: "HUD")
    static let battery = Logger(subsystem: subsystem, category: "Battery")
    static let bluetooth = Logger(subsystem: subsystem, category: "Bluetooth")
}
