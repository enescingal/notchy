struct BatteryReading: Equatable {
    var percentage: Int
    var isCharging: Bool
    var isPluggedIn: Bool
}

/// Turns successive power-source readings into user-facing events.
struct BatteryEventDetector {
    static let lowThresholds = [20, 10]

    private var previous: BatteryReading?
    private var announcedThresholds: Set<Int> = []

    mutating func process(_ reading: BatteryReading) -> BatteryEvent? {
        defer { previous = reading }
        guard let last = previous else {
            if !reading.isPluggedIn { announcedThresholds = Self.thresholds(atOrAbove: reading.percentage) }
            return nil
        }

        if reading.isPluggedIn != last.isPluggedIn {
            if reading.isPluggedIn {
                announcedThresholds.removeAll()
                return BatteryEvent(kind: .pluggedIn, percentage: reading.percentage, isCharging: reading.isCharging)
            }
            announcedThresholds = Self.thresholds(atOrAbove: reading.percentage)
            return BatteryEvent(kind: .unplugged, percentage: reading.percentage, isCharging: false)
        }

        guard !reading.isPluggedIn else { return nil }
        let crossed = Self.thresholds(atOrAbove: reading.percentage).subtracting(announcedThresholds)
        guard !crossed.isEmpty else { return nil }
        announcedThresholds.formUnion(crossed)
        return BatteryEvent(kind: .low, percentage: reading.percentage, isCharging: false)
    }

    /// Thresholds the given percentage has reached (percentage <= threshold).
    private static func thresholds(atOrAbove percentage: Int) -> Set<Int> {
        Set(lowThresholds.filter { percentage <= $0 })
    }
}
