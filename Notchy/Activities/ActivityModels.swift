import Foundation

enum HUDKind: Equatable {
    case volume, brightness
}

struct HUDState: Equatable {
    var kind: HUDKind
    /// 0...1
    var level: Double
    var isMuted: Bool = false
}

enum BatteryEventKind: Equatable {
    case pluggedIn, unplugged, low
}

struct BatteryEvent: Equatable {
    var kind: BatteryEventKind
    var percentage: Int
    var isCharging: Bool
}

enum DeviceKind: Equatable {
    case airpods, airpodsPro, airpodsMax, headphones, other
}

struct BluetoothBattery: Equatable {
    var left: Int?
    var right: Int?
    var caseLevel: Int?
    var single: Int?

    var isEmpty: Bool { left == nil && right == nil && caseLevel == nil && single == nil }
}

struct BluetoothEvent: Equatable {
    var name: String
    var kind: DeviceKind
    var isConnected: Bool
    var battery: BluetoothBattery?
}

struct MediaState: Equatable {
    var title: String
    var artist: String?
    var isPlaying: Bool
    var bundleIdentifier: String?
}

/// Raw values are mediaremote-adapter `send` command IDs.
enum MediaCommand: Int, Equatable {
    case togglePlayPause = 2
    case next = 4
    case previous = 5
}
