import Combine
import Foundation

/// A button in the expanded island's control row.
enum QuickControl: CaseIterable {
    case brightnessDown, brightnessUp, volumeDown, volumeUp, lockScreen
}

/// Current levels shown between the buttons; nil while a control is unavailable.
struct ControlLevels: Equatable {
    var brightness: Double?
    var volume: Double?
}

@MainActor
protocol VolumeStepping: AnyObject {
    var canSetVolume: Bool { get }
    var current: HUDState { get }
    var onChange: ((HUDState) -> Void)? { get set }
    func start()
    func step(up: Bool, fine: Bool)
}

@MainActor
protocol BrightnessStepping: AnyObject {
    var isUsable: Bool { get }
    var current: HUDState? { get }
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
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: NotchViewModel, volume: VolumeStepping, brightness: BrightnessStepping?, locker: ScreenLocking?) {
        self.viewModel = viewModel
        self.volume = volume
        self.brightness = brightness
        self.locker = locker
    }

    func start() {
        volume.onChange = { [weak self] state in self?.viewModel?.controlLevels.volume = Self.shownLevel(state) }
        volume.start()
        viewModel?.controlHandler = { [weak self] control in self?.perform(control) }
        // The lid or the output device can change while the island is closed, so check again
        // every time it opens.
        viewModel?.$state
            .filter { $0 == .expanded }
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        // Brightness has no change notification; brightness keys pressed while the island is
        // open arrive here as the expanded HUD.
        viewModel?.$expandedHUD
            .compactMap { $0 }
            .filter { $0.kind == .brightness }
            .sink { [weak self] hud in self?.viewModel?.controlLevels.brightness = hud.level }
            .store(in: &cancellables)
        refresh()
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
        refresh()
    }

    /// Re-reads which controls work right now and their current levels.
    private func refresh() {
        var available = Set<QuickControl>()
        var levels = ControlLevels()
        if let brightness, brightness.isUsable {
            available.formUnion([.brightnessDown, .brightnessUp])
            levels.brightness = brightness.current?.level
        }
        if volume.canSetVolume {
            available.formUnion([.volumeDown, .volumeUp])
            levels.volume = Self.shownLevel(volume.current)
        }
        if locker != nil { available.insert(.lockScreen) }
        viewModel?.availableControls = available
        viewModel?.controlLevels = levels
    }

    /// A muted output shows as zero.
    private static func shownLevel(_ state: HUDState) -> Double {
        state.isMuted ? 0 : state.level
    }
}
