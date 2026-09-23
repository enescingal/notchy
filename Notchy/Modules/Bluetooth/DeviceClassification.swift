extension DeviceKind {
    /// Bluetooth Class of Device major class "Audio/Video".
    static let audioMajorClass: UInt32 = 0x04

    static func classify(name: String, majorClass: UInt32) -> DeviceKind {
        let lowered = name.lowercased()
        if lowered.contains("airpods max") { return .airpodsMax }
        if lowered.contains("airpods pro") { return .airpodsPro }
        if lowered.contains("airpods") { return .airpods }
        if majorClass == audioMajorClass { return .headphones }
        return .other
    }

    var isAudio: Bool { self != .other }
}
