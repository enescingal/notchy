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

    func step(up: Bool, fine: Bool) -> HUDState? {
        var current: Float = 0
        guard getBrightness(display, &current) == 0 else { return nil }
        let next = HUDStep.next(from: Double(current), up: up, fine: fine)
        guard setBrightness(display, Float(next)) == 0 else { return nil }
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
