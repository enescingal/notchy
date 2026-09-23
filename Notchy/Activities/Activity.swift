enum ActivityPriority: Int, Comparable {
    case media = 0, battery = 1, bluetooth = 2, timer = 3, hud = 4

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum PeekContent: Equatable {
    case hud(HUDState)
    case battery(BatteryEvent)
    case bluetooth(BluetoothEvent)
    case timerDone

    var priority: ActivityPriority {
        switch self {
        case .hud: return .hud
        case .battery: return .battery
        case .bluetooth: return .bluetooth
        case .timerDone: return .timer
        }
    }

    var isHUD: Bool {
        if case .hud = self { return true }
        return false
    }
}
