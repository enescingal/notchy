enum ActivityPriority: Int, Comparable {
    case media = 0, battery = 1, bluetooth = 2, hud = 3

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum PeekContent: Equatable {
    case hud(HUDState)
    case battery(BatteryEvent)
    case bluetooth(BluetoothEvent)

    var priority: ActivityPriority {
        switch self {
        case .hud: return .hud
        case .battery: return .battery
        case .bluetooth: return .bluetooth
        }
    }

    var isHUD: Bool {
        if case .hud = self { return true }
        return false
    }
}
