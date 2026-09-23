import Foundation
import Combine

enum ModuleID: String, CaseIterable {
    case media, hud, battery, bluetooth
}

@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let media = "module.media.enabled"
        static let hud = "module.hud.enabled"
        static let battery = "module.battery.enabled"
        static let bluetooth = "module.bluetooth.enabled"
        static let hoverDelay = "behavior.hoverDelay"
        static let peekDuration = "behavior.peekDuration"
        static let onboarding = "onboarding.completed"
    }

    private let defaults: UserDefaults

    @Published var mediaEnabled: Bool { didSet { defaults.set(mediaEnabled, forKey: Keys.media) } }
    @Published var hudEnabled: Bool { didSet { defaults.set(hudEnabled, forKey: Keys.hud) } }
    @Published var batteryEnabled: Bool { didSet { defaults.set(batteryEnabled, forKey: Keys.battery) } }
    @Published var bluetoothEnabled: Bool { didSet { defaults.set(bluetoothEnabled, forKey: Keys.bluetooth) } }
    @Published var hoverDelay: Double { didSet { defaults.set(hoverDelay, forKey: Keys.hoverDelay) } }
    @Published var peekDuration: Double { didSet { defaults.set(peekDuration, forKey: Keys.peekDuration) } }
    @Published var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) } }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.media: true, Keys.hud: true, Keys.battery: true, Keys.bluetooth: true,
            Keys.hoverDelay: 0.1, Keys.peekDuration: 3.0, Keys.onboarding: false,
        ])
        mediaEnabled = defaults.bool(forKey: Keys.media)
        hudEnabled = defaults.bool(forKey: Keys.hud)
        batteryEnabled = defaults.bool(forKey: Keys.battery)
        bluetoothEnabled = defaults.bool(forKey: Keys.bluetooth)
        hoverDelay = defaults.double(forKey: Keys.hoverDelay)
        peekDuration = defaults.double(forKey: Keys.peekDuration)
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
    }

    func isEnabled(_ id: ModuleID) -> Bool {
        switch id {
        case .media: return mediaEnabled
        case .hud: return hudEnabled
        case .battery: return batteryEnabled
        case .bluetooth: return bluetoothEnabled
        }
    }

    var notchConfiguration: NotchConfiguration {
        NotchConfiguration(hoverDelay: hoverDelay, peekDuration: peekDuration)
    }
}
