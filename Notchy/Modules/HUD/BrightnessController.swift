import CoreGraphics
import Foundation

/// Built-in display brightness through the private DisplayServices framework (loaded at runtime).
@MainActor
final class BrightnessController {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let getBrightness: GetBrightness
    private let setBrightness: SetBrightness
    private let display: CGDirectDisplayID

    init?() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let get = dlsym(handle, "DisplayServicesGetBrightness"),
              let set = dlsym(handle, "DisplayServicesSetBrightness"),
              let display = Self.builtInDisplay() else {
            Log.hud.error("DisplayServices yüklenemedi; parlaklık tuşları sisteme bırakılıyor")
            return nil
        }
        getBrightness = unsafeBitCast(get, to: GetBrightness.self)
        setBrightness = unsafeBitCast(set, to: SetBrightness.self)
        self.display = display
    }

    /// Whether the built-in display is currently able to report/set brightness (e.g. false in
    /// clamshell mode with only an external display attached).
    var isUsable: Bool {
        CGDisplayIsOnline(display) != 0
    }

    /// The built-in display's brightness right now, or nil if it can't be read.
    var current: HUDState? {
        var value: Float = 0
        guard getBrightness(display, &value) == 0 else { return nil }
        return HUDState(kind: .brightness, level: Double(value))
    }

    func step(up: Bool, fine: Bool) -> HUDState? {
        var current: Float = 0
        let getStatus = getBrightness(display, &current)
        guard getStatus == 0 else {
            Log.hud.error("Parlaklık okunamadı: \(getStatus)")
            return nil
        }
        let next = HUDStep.next(from: Double(current), up: up, fine: fine)
        let setStatus = setBrightness(display, Float(next))
        guard setStatus == 0 else {
            Log.hud.error("Parlaklık ayarlanamadı: \(setStatus)")
            return nil
        }
        return HUDState(kind: .brightness, level: next)
    }

    private static func builtInDisplay() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        return ids.first { CGDisplayIsBuiltin($0) != 0 }
    }
}
