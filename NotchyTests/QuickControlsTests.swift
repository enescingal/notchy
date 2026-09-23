import XCTest
@testable import Notchy

@MainActor
private final class FakeVolume: VolumeStepping {
    var canSetVolume = true
    var current = HUDState(kind: .volume, level: 0.5)
    var onChange: ((HUDState) -> Void)?
    private(set) var started = false
    private(set) var steps: [Bool] = []
    func start() { started = true }
    func step(up: Bool, fine: Bool) { steps.append(up) }
}

@MainActor
private final class FakeBrightness: BrightnessStepping {
    var isUsable = true
    var level = 0.3
    private(set) var steps: [Bool] = []
    var current: HUDState? { HUDState(kind: .brightness, level: level) }
    func step(up: Bool, fine: Bool) -> HUDState? {
        steps.append(up)
        level = up ? 0.6 : 0.4
        return HUDState(kind: .brightness, level: level)
    }
}

@MainActor
private final class FakeLocker: ScreenLocking {
    private(set) var lockCount = 0
    func lock() { lockCount += 1 }
}

@MainActor
final class QuickControlsTests: XCTestCase {
    private var scheduler: ManualScheduler!
    private var vm: NotchViewModel!
    private var volume: FakeVolume!
    private var brightness: FakeBrightness!
    private var locker: FakeLocker!
    private var controls: QuickControls!

    override func setUp() async throws {
        scheduler = ManualScheduler()
        vm = NotchViewModel(scheduler: scheduler)
        volume = FakeVolume()
        brightness = FakeBrightness()
        locker = FakeLocker()
    }

    private func startControls(brightness: BrightnessStepping?, locker: ScreenLocking?) {
        controls = QuickControls(viewModel: vm, volume: volume, brightness: brightness, locker: locker)
        controls.start()
    }

    func testStartStartsVolumeAndPublishesEveryAvailableControl() {
        startControls(brightness: brightness, locker: locker)
        XCTAssertTrue(volume.started)
        XCTAssertEqual(vm.availableControls, Set(QuickControl.allCases))
    }

    func testVolumeButtonsStepAndShowTheHUD() {
        startControls(brightness: brightness, locker: locker)
        vm.perform(.volumeUp)
        vm.perform(.volumeDown)
        XCTAssertEqual(volume.steps, [true, false])
        XCTAssertEqual(vm.state, .peek(.hud(volume.current)))
    }

    func testBrightnessButtonsStepAndShowTheHUD() {
        startControls(brightness: brightness, locker: locker)
        vm.perform(.brightnessUp)
        XCTAssertEqual(brightness.steps, [true])
        XCTAssertEqual(vm.state, .peek(.hud(HUDState(kind: .brightness, level: 0.6))))
    }

    func testLockButtonLocksTheScreen() {
        startControls(brightness: brightness, locker: locker)
        vm.perform(.lockScreen)
        XCTAssertEqual(locker.lockCount, 1)
    }

    func testUnavailableControlsAreLeftOutAndDoNothing() {
        volume.canSetVolume = false
        brightness.isUsable = false
        startControls(brightness: brightness, locker: nil)
        XCTAssertEqual(vm.availableControls, [])
        vm.perform(.volumeUp)
        vm.perform(.brightnessUp)
        XCTAssertEqual(volume.steps, [])
        XCTAssertEqual(brightness.steps, [])
        XCTAssertEqual(vm.state, .closed)
    }

    func testMissingBrightnessControllerDisablesOnlyBrightness() {
        startControls(brightness: nil, locker: locker)
        XCTAssertEqual(vm.availableControls, [.volumeDown, .volumeUp, .lockScreen])
    }

    func testAvailabilityIsRefreshedWhenTheIslandExpands() {
        startControls(brightness: brightness, locker: locker)
        brightness.isUsable = false // e.g. the lid was closed in the meantime
        vm.hoverChanged(true)
        scheduler.advance(by: vm.configuration.hoverDelay)
        XCTAssertEqual(vm.state, .expanded)
        XCTAssertEqual(vm.availableControls, [.volumeDown, .volumeUp, .lockScreen])
    }

    func testStartShowsTheCurrentLevels() {
        startControls(brightness: brightness, locker: locker)
        XCTAssertEqual(vm.controlLevels, ControlLevels(brightness: 0.3, volume: 0.5))
    }

    func testVolumeChangesFromAnywhereUpdateTheLevel() {
        startControls(brightness: brightness, locker: locker)
        volume.onChange?(HUDState(kind: .volume, level: 0.7))
        XCTAssertEqual(vm.controlLevels.volume, 0.7)
        volume.onChange?(HUDState(kind: .volume, level: 0.7, isMuted: true))
        XCTAssertEqual(vm.controlLevels.volume, 0, "muted shows as zero")
    }

    func testBrightnessButtonUpdatesTheLevel() {
        startControls(brightness: brightness, locker: locker)
        vm.perform(.brightnessUp)
        XCTAssertEqual(vm.controlLevels.brightness, 0.6)
    }

    func testBrightnessKeysWhileExpandedUpdateTheLevel() {
        startControls(brightness: brightness, locker: locker)
        vm.hoverChanged(true)
        scheduler.advance(by: vm.configuration.hoverDelay)
        vm.present(.hud(HUDState(kind: .brightness, level: 0.9)))
        XCTAssertEqual(vm.controlLevels.brightness, 0.9)
    }

    func testUnavailableControlsShowNoLevel() {
        volume.canSetVolume = false
        brightness.isUsable = false
        startControls(brightness: brightness, locker: nil)
        XCTAssertEqual(vm.controlLevels, ControlLevels())
    }
}
