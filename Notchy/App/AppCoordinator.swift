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
    private let settingsWindow = WindowPresenter()
    private let onboardingWindow = WindowPresenter()
    private var modules: [ModuleID: NotchModule] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(settings: SettingsStore) {
        self.settings = settings
        self.viewModel = NotchViewModel(scheduler: scheduler)
    }

    func start() {
        menuBar = MenuBarController(onSettings: { [weak self] in self?.showSettings() })
        panelController.onNotchAvailabilityChange = { [weak self] hasNotch in
            self?.status.hasNotch = hasNotch
            self?.menuBar?.setHasNotch(hasNotch)
        }
        panelController.start()
        applySettings()

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applySettings() }
            .store(in: &cancellables)
        DistributedNotificationCenter.default().publisher(for: Accessibility.trustChangedNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.accessibilityMayHaveChanged() }
            .store(in: &cancellables)

        if !settings.hasCompletedOnboarding { showOnboarding() }
    }

    func stopAll() {
        modules.values.forEach { $0.stop() }
        modules.removeAll()
    }

    private func applySettings() {
        viewModel.configuration = settings.notchConfiguration
        for id in ModuleID.allCases {
            let shouldRun = settings.isEnabled(id)
            if shouldRun, modules[id] == nil, let module = makeModule(id) {
                modules[id] = module
                module.start()
            } else if !shouldRun, let module = modules.removeValue(forKey: id) {
                module.stop()
            }
        }
    }

    private func restartModule(_ id: ModuleID) {
        modules.removeValue(forKey: id)?.stop()
        applySettings()
    }

    /// The notification arrives slightly before the trust flag flips, so re-check after a second.
    private func accessibilityMayHaveChanged() {
        scheduler.schedule(after: 1.0) { [weak self] in
            guard let self else { return }
            let granted = Accessibility.isTrusted
            guard granted != self.status.accessibilityGranted else { return }
            self.status.accessibilityGranted = granted
            self.restartModule(.hud)
        }
    }

    private func makeModule(_ id: ModuleID) -> NotchModule? {
        switch id {
        case .media: return nil
        case .hud: return HUDModule(viewModel: viewModel)
        case .battery: return BatteryModule(viewModel: viewModel)
        case .bluetooth: return BluetoothModule(viewModel: viewModel, scheduler: scheduler)
        }
    }

    private func showSettings() {
        status.accessibilityGranted = Accessibility.isTrusted
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
