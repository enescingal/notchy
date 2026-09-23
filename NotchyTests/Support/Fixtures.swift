@testable import Notchy

enum Fixtures {
    static func volume(_ level: Double) -> PeekContent { .hud(HUDState(kind: .volume, level: level)) }
    static let pluggedIn = PeekContent.battery(BatteryEvent(kind: .pluggedIn, percentage: 50, isCharging: true))
    static let airpods = PeekContent.bluetooth(BluetoothEvent(name: "AirPods", kind: .airpods, isConnected: true, battery: nil))
    static let song = MediaState(title: "Song", artist: "Artist", isPlaying: true, bundleIdentifier: "com.spotify.client")
}
