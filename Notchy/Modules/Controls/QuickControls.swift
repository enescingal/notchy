import Combine
import Foundation

/// A button in the expanded island's control row.
enum QuickControl: CaseIterable {
    case brightnessDown, brightnessUp, volumeDown, volumeUp, lockScreen
}

@MainActor
protocol VolumeStepping: AnyObject {
    var canSetVolume: Bool { get }
    var current: HUDState { get }
    func start()
    func step(up: Bool, fine: Bool)
}

@MainActor
protocol BrightnessStepping: AnyObject {
    var isUsable: Bool { get }
    func step(up: Bool, fine: Bool) -> HUDState?
}

@MainActor
protocol ScreenLocking: AnyObject {
    func lock()
}

extension VolumeController: VolumeStepping {}
extension BrightnessController: BrightnessStepping {}

/// Drives the control row. Always on: independent of module settings and Accessibility trust.
@MainActor
final class QuickControls {
    private weak var viewModel: NotchViewModel?
    private let volume: VolumeStepping
    private let brightness: BrightnessStepping?
    private let locker: ScreenLocking?
    private var cancellable: AnyCancellable?

    init(viewModel: NotchViewModel, volume: VolumeStepping, brightness: BrightnessStepping?, locker: ScreenLocking?) {
        self.viewModel = viewModel
        self.volume = volume
        self.brightness = brightness
        self.locker = locker
    }

    func start() {
        volume.start()
        viewModel?.controlHandler = { [weak self] control in self?.perform(control) }
        // The lid or the output device can change while the island is closed, so check again
        // every time it opens.
        cancellable = viewModel?.$state
            .filter { $0 == .expanded }
            .sink { [weak self] _ in self?.refreshAvailability() }
        refreshAvailability()
    }

    private func perform(_ control: QuickControl) {
        switch control {
        case .brightnessDown, .brightnessUp:
            if let brightness, brightness.isUsable,
               let state = brightness.step(up: control == .brightnessUp, fine: false) {
                viewModel?.present(.hud(state))
            }
        case .volumeDown, .volumeUp:
            if volume.canSetVolume {
                volume.step(up: control == .volumeUp, fine: false)
                viewModel?.present(.hud(volume.current))
            }
        case .lockScreen:
            locker?.lock()
        }
        refreshAvailability()
    }

    private func refreshAvailability() {
        var available = Set<QuickControl>()
        if let brightness, brightness.isUsable { available.formUnion([.brightnessDown, .brightnessUp]) }
        if volume.canSetVolume { available.formUnion([.volumeDown, .volumeUp]) }
        if locker != nil { available.insert(.lockScreen) }
        viewModel?.availableControls = available
    }
}
