import AppKit
import Combine

@MainActor
final class AppCoordinator {
    let settings: SettingsStore
    let status = ModuleStatus()
    let scheduler = MainScheduler()
    let viewModel: NotchViewModel

    private lazy var panelController = NotchPanelController(viewModel: viewModel)
    private var menuBar: MenuBarController?
    private var quickControls: QuickControls?
    private let settingsWindow = WindowPresenter()
    private let onboardingWindow = WindowPresenter()
    private let lifecycle: ModuleLifecycle
    private var cancellables = Set<AnyCancellable>()

    init(settings: SettingsStore) {
        self.settings = settings
        self.viewModel = NotchViewModel(scheduler: scheduler)
        let viewModel = self.viewModel
        let status = self.status
        let scheduler = self.scheduler
        self.lifecycle = ModuleLifecycle(
            settings: settings, status: status, viewModel: viewModel,
            isTrusted: { Accessibility.isTrusted },
            makeModule: { id in AppCoordinator.makeModule(id, viewModel: viewModel, status: status, scheduler: scheduler) })
    }

    func start() {
        menuBar = MenuBarController(onSettings: { [weak self] in self?.showSettings() })
        // rebuild() (called synchronously by panelController.start() below) always reports the
        // first availability, so it also performs the very first applySettings().
        panelController.onScreenAvailabilityChange = { [weak self] hasScreen in
            self?.lifecycle.setHasScreen(hasScreen)
        }
        panelController.start()
        quickControls = QuickControls(viewModel: viewModel, volume: VolumeController(),
                                      brightness: BrightnessController(), locker: ScreenLocker())
        quickControls?.start()

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.lifecycle.applySettings() }
            .store(in: &cancellables)
        DistributedNotificationCenter.default().publisher(for: Accessibility.trustChangedNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleAccessibilityRefresh() }
            .store(in: &cancellables)

        if !settings.hasCompletedOnboarding { showOnboarding() }
    }

    func stopAll() {
        lifecycle.stopAll()
    }

    /// The notification arrives slightly before the trust flag flips, so re-check after a
    /// second, and once more after three in case it takes even longer.
    private func scheduleAccessibilityRefresh() {
        scheduler.schedule(after: 1.0) { [weak self] in self?.lifecycle.refreshAccessibility() }
        scheduler.schedule(after: 3.0) { [weak self] in self?.lifecycle.refreshAccessibility() }
    }

    private static func makeModule(_ id: ModuleID, viewModel: NotchViewModel, status: ModuleStatus, scheduler: Scheduler) -> NotchModule? {
        switch id {
        case .media:
            return MediaModule(viewModel: viewModel, status: status, makeSource: {
                MediaRemoteAdapterSource(scheduler: scheduler)
            })
        case .hud: return HUDModule(viewModel: viewModel)
        case .battery: return BatteryModule(viewModel: viewModel)
        case .bluetooth: return BluetoothModule(viewModel: viewModel, scheduler: scheduler)
        }
    }

    private func showSettings() {
        lifecycle.refreshAccessibility()
        settingsWindow.show(title: "Notchy Ayarları") {
            SettingsView(settings: settings, status: status)
        }
    }

    private func showOnboarding() {
        onboardingWindow.show(title: "Notchy") {
            OnboardingView(status: status) { [weak self] in
                self?.settings.hasCompletedOnboarding = true
                self?.onboardingWindow.close()
            }
        }
    }
}

/// Decides which modules run, driven by user settings, screen availability, and Accessibility
/// trust. Extracted from `AppCoordinator` so the policy (start/stop bookkeeping, accessibility
/// restart) can be unit tested without touching AppKit (menu bar, windows, real screen
/// detection) — it only needs a settings store and two injectable seams: the module factory
/// and an `isTrusted` provider.
@MainActor
final class ModuleLifecycle {
    private let settings: SettingsStore
    private let status: ModuleStatus
    private let viewModel: NotchViewModel
    private let isTrusted: () -> Bool
    private let makeModule: (ModuleID) -> NotchModule?

    private var modules: [ModuleID: NotchModule] = [:]
    /// Accessibility trust the *currently running* HUD module was started with. Compared
    /// against the live trust value in `refreshAccessibility()` so a real change is detected
    /// even if `status.accessibilityGranted` (the UI-facing flag) was already overwritten
    /// elsewhere (e.g. by opening Settings) without a restart.
    private var hudStartedWithTrust: Bool?

    init(settings: SettingsStore, status: ModuleStatus, viewModel: NotchViewModel,
         isTrusted: @escaping () -> Bool, makeModule: @escaping (ModuleID) -> NotchModule?) {
        self.settings = settings
        self.status = status
        self.viewModel = viewModel
        self.isTrusted = isTrusted
        self.makeModule = makeModule
    }

    /// Nothing can be shown without the island, so no module may run without a screen for it.
    func setHasScreen(_ hasScreen: Bool) {
        status.hasScreen = hasScreen
        applySettings()
    }

    func applySettings() {
        viewModel.configuration = settings.notchConfiguration
        for id in ModuleID.allCases {
            let shouldRun = settings.isEnabled(id) && status.hasScreen
            if shouldRun, modules[id] == nil, let module = makeModule(id) {
                modules[id] = module
                module.start()
                if id == .hud { hudStartedWithTrust = isTrusted() }
            } else if !shouldRun, let module = modules.removeValue(forKey: id) {
                module.stop()
                if id == .hud { hudStartedWithTrust = nil }
            }
        }
    }

    func refreshAccessibility() {
        let granted = isTrusted()
        status.accessibilityGranted = granted
        if let hudStartedWithTrust, hudStartedWithTrust != granted {
            restartModule(.hud)
        }
    }

    func stopAll() {
        modules.values.forEach { $0.stop() }
        modules.removeAll()
        hudStartedWithTrust = nil
    }

    private func restartModule(_ id: ModuleID) {
        if let module = modules.removeValue(forKey: id) {
            module.stop()
            if id == .hud { hudStartedWithTrust = nil }
        }
        applySettings()
    }
}
