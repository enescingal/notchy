import Foundation

@MainActor
final class HUDModule: NotchModule {
    private weak var viewModel: NotchViewModel?
    private let volume = VolumeController()
    private let brightness = BrightnessController()
    private let keyTap = MediaKeyTap()

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        // External changes (Control Center, other apps) show the HUD too — this is also the
        // whole feature when Accessibility is not granted ("observe only" mode).
        volume.onChange = { [weak self] state in self?.viewModel?.present(.hud(state)) }
        volume.start()
        keyTap.handler = { [weak self] event, fine in self?.handle(event, fine: fine) ?? false }
        if !keyTap.start() {
            Log.hud.info("Erişilebilirlik izni yok; HUD yalnızca gözlem modunda")
        }
    }

    func stop() {
        keyTap.stop()
        volume.stop()
    }

    private func handle(_ event: MediaKeyEvent, fine: Bool) -> Bool {
        switch event.key {
        case .volumeUp, .volumeDown, .mute:
            guard volume.canSetVolume else { return false }
            if event.isDown {
                switch event.key {
                case .volumeUp: volume.step(up: true, fine: fine)
                case .volumeDown: volume.step(up: false, fine: fine)
                default: if !event.isRepeat { volume.toggleMute() }
                }
                // Show the HUD even at the limits, where the volume does not change.
                viewModel?.present(.hud(volume.current))
            }
            return true
        case .brightnessUp, .brightnessDown:
            // Not swallowing here (e.g. clamshell mode with only an external display) lets the
            // system fall back to its own handling; the same gate applies to the matching
            // key-up so we never swallow one half of a down/up pair.
            guard let brightness, brightness.isUsable else { return false }
            guard event.isDown else { return true }
            guard let state = brightness.step(up: event.key == .brightnessUp, fine: fine) else { return false }
            viewModel?.present(.hud(state))
            return true
        }
    }
}
