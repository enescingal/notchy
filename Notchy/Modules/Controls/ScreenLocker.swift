import Foundation

/// Locks the screen at once through the private login framework (loaded at runtime).
@MainActor
final class ScreenLocker: ScreenLocking {
    private typealias LockScreen = @convention(c) () -> Int32
    private let lockScreen: LockScreen

    init?() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
              let symbol = dlsym(handle, "SACLockScreenImmediate") else {
            Log.controls.error("login.framework yüklenemedi; kilit düğmesi devre dışı")
            return nil
        }
        lockScreen = unsafeBitCast(symbol, to: LockScreen.self)
    }

    func lock() {
        let status = lockScreen()
        if status != 0 { Log.controls.error("Ekran kilitlenemedi: \(status)") }
    }
}
