/// Raw values are NX_KEYTYPE_* codes.
enum MediaKey: Int {
    case volumeUp = 0
    case volumeDown = 1
    case brightnessUp = 2
    case brightnessDown = 3
    case mute = 7
}

struct MediaKeyEvent: Equatable {
    var key: MediaKey
    var isDown: Bool
    var isRepeat: Bool
}

enum MediaKeyParser {
    /// NX_SYSDEFINED
    static let systemDefinedEventType: UInt32 = 14
    /// NX_SUBTYPE_AUX_CONTROL_BUTTONS
    static let auxControlSubtype: Int16 = 8

    static func parse(subtype: Int16, data1: Int) -> MediaKeyEvent? {
        guard subtype == auxControlSubtype else { return nil }
        let keyCode = (data1 & 0xFFFF_0000) >> 16
        let flags = data1 & 0x0000_FFFF
        guard let key = MediaKey(rawValue: keyCode) else { return nil }
        let state = (flags & 0xFF00) >> 8
        return MediaKeyEvent(key: key, isDown: state == 0x0A, isRepeat: flags & 0x1 == 1)
    }

    /// Apple Silicon keyboards may report brightness as regular key codes instead of NX_SYSDEFINED.
    static func brightnessKey(forKeyCode keyCode: Int64) -> MediaKey? {
        switch keyCode {
        case 144: return .brightnessUp
        case 145: return .brightnessDown
        default: return nil
        }
    }
}
