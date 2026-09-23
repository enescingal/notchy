import XCTest
@testable import Notchy

@MainActor
private final class FakeModule: NotchModule {
    private(set) var started = false
    private(set) var stopped = false
    func start() { started = true }
    func stop() { stopped = true }
}

/// Records every fake module `ModuleLifecycle` creates, in creation order per id, so a test
/// can tell a freshly-created instance (after a restart) apart from the one that was running
/// before it.
@MainActor
private final class ModuleFactorySpy {
    private(set) var created: [ModuleID: [FakeModule]] = [:]

    func makeModule(_ id: ModuleID) -> NotchModule? {
        let fake = FakeModule()
        created[id, default: []].append(fake)
        return fake
    }

    func instances(_ id: ModuleID) -> [FakeModule] { created[id] ?? [] }
}

@MainActor
final class ModuleLifecycleTests: XCTestCase {
    private func makeSettings() -> SettingsStore {
        SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    private func makeLifecycle(
        settings: SettingsStore, status: ModuleStatus, spy: ModuleFactorySpy,
        isTrusted: @escaping () -> Bool = { true }
    ) -> ModuleLifecycle {
        ModuleLifecycle(
            settings: settings, status: status, viewModel: NotchViewModel(scheduler: ManualScheduler()),
            isTrusted: isTrusted, makeModule: spy.makeModule)
    }

    // MARK: - Finding 1: nothing may run without a notch.

    func testNoModuleStartsWithoutANotch() {
        let settings = makeSettings()
        let status = ModuleStatus()
        let spy = ModuleFactorySpy()
        let lifecycle = makeLifecycle(settings: settings, status: status, spy: spy)

        lifecycle.setHasNotch(false)

        for id in ModuleID.allCases {
            XCTAssertTrue(spy.instances(id).isEmpty, "\(id) must not run without a notch")
        }
    }

    func testModulesStartWhenNotchAppearsAndStopWhenItDisappears() {
        let settings = makeSettings()
        let status = ModuleStatus()
        let spy = ModuleFactorySpy()
        let lifecycle = makeLifecycle(settings: settings, status: status, spy: spy)

        lifecycle.setHasNotch(false)
        XCTAssertTrue(spy.instances(.hud).isEmpty)

        lifecycle.setHasNotch(true)
        XCTAssertEqual(spy.instances(.hud).count, 1)
        XCTAssertTrue(spy.instances(.hud)[0].started)

        lifecycle.setHasNotch(false)
        XCTAssertTrue(spy.instances(.hud)[0].stopped, "HUD must stop again once the notch is gone")
    }

    // MARK: - Finding 2: an accessibility grant while running must restart the HUD reliably.

    func testRefreshAccessibilityRestartsHUDWhenLiveTrustDiffersFromWhatItStartedWith() {
        let settings = makeSettings()
        let status = ModuleStatus()
        let spy = ModuleFactorySpy()
        var trusted = false
        let lifecycle = makeLifecycle(settings: settings, status: status, spy: spy, isTrusted: { trusted })

        lifecycle.setHasNotch(true) // HUD starts observe-only, with trusted == false
        XCTAssertEqual(spy.instances(.hud).count, 1)
        let firstHUD = spy.instances(.hud)[0]

        // Simulate the UI-facing flag already having been overwritten independently (e.g. by
        // `showSettings()` sampling it, or an earlier 1s sample) — this must NOT be what
        // `refreshAccessibility` compares against, or a later real change would be missed.
        status.accessibilityGranted = true

        trusted = true // TCC actually flips now
        lifecycle.refreshAccessibility()

        XCTAssertTrue(firstHUD.stopped, "the HUD module started without trust must be stopped")
        XCTAssertEqual(spy.instances(.hud).count, 2, "a new HUD module must be started with the new trust state")
        XCTAssertTrue(spy.instances(.hud)[1].started)
        XCTAssertTrue(status.accessibilityGranted)
    }

    func testRefreshAccessibilityDoesNotRestartWhenTrustMatchesWhatHUDStartedWith() {
        let settings = makeSettings()
        let status = ModuleStatus()
        let spy = ModuleFactorySpy()
        let lifecycle = makeLifecycle(settings: settings, status: status, spy: spy, isTrusted: { true })

        lifecycle.setHasNotch(true)
        XCTAssertEqual(spy.instances(.hud).count, 1)

        lifecycle.refreshAccessibility()
        lifecycle.refreshAccessibility()

        XCTAssertEqual(spy.instances(.hud).count, 1, "must not restart when trust hasn't actually changed")
        XCTAssertFalse(spy.instances(.hud)[0].stopped)
    }
}
