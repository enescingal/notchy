# Quick Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a control row that is always at the top of the expanded island. It has buttons to lower and raise brightness, lower and raise volume, and lock the screen. When media exists, the media row sits under it.

**Architecture:**
- `QuickControls` is always on and ignores module settings. It owns its own `VolumeController`, a `BrightnessController` and a `ScreenLocker`. Each one sits behind a small protocol so tests can swap in fakes.
- `QuickControls` connects to `NotchViewModel` the same way media does: through a handler (`controlHandler`) and a published `availableControls` set.
- The expanded island adds a 36 pt row when media exists.

**Tech Stack:** Swift (Swift 5 mode), SwiftUI, CoreAudio, private DisplayServices and login frameworks (dlopen), XCTest.

**Spec:** `docs/superpowers/specs/2026-09-23-quick-controls-design.md`

## Global Constraints

- Deployment target macOS 14.0. No new dependencies and no polling timers.
- Row: `sun.min.fill` `sun.max.fill` · `speaker.wave.1.fill` `speaker.wave.3.fill` · `lock.fill`. Symbols are 13 pt semibold white, each button is 28×28, spacing is 2 pt inside a group and 16 pt between groups. An unavailable button is drawn at 30% opacity and is disabled.
- A step is 1/16 (`fine: false`). After every brightness or volume step, the new level is shown with `present(.hud(...))`.
- Heights: `expandedExtraHeight = 48`, and `expandedRowHeight = 36` is added when `media != nil`. Rows are spaced 8 pt apart and centered vertically.
- The controls ignore module settings and Accessibility trust.
- User-facing strings are in Turkish.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- Test command: `scripts/test.sh`, optionally with `-only-testing:NotchyTests/<Class>`. Exit status 0 means success.

---

### Task 1: Quick controls logic

**Files:**
- Create: `Notchy/Modules/Controls/QuickControls.swift`
- Create: `Notchy/Modules/Controls/ScreenLocker.swift`
- Modify: `Notchy/App/Log.swift`
- Modify: `Notchy/Notch/NotchViewModel.swift`
- Test: `NotchyTests/QuickControlsTests.swift` (create)

**Interfaces:**
- Produces:
  - `enum QuickControl: CaseIterable { brightnessDown, brightnessUp, volumeDown, volumeUp, lockScreen }`
  - `NotchViewModel.availableControls: Set<QuickControl>` (published)
  - `NotchViewModel.controlHandler: ((QuickControl) -> Void)?`
  - `NotchViewModel.perform(_:)`
  - `QuickControls(viewModel:volume:brightness:locker:)`, with `.start()`
  - `ScreenLocker()`, a failable initializer

- [ ] **Step 1: Write the failing tests.** Create `NotchyTests/QuickControlsTests.swift`:

```swift
import XCTest
@testable import Notchy

@MainActor
private final class FakeVolume: VolumeStepping {
    var canSetVolume = true
    var current = HUDState(kind: .volume, level: 0.5)
    private(set) var started = false
    private(set) var steps: [Bool] = []
    func start() { started = true }
    func step(up: Bool, fine: Bool) { steps.append(up) }
}

@MainActor
private final class FakeBrightness: BrightnessStepping {
    var isUsable = true
    private(set) var steps: [Bool] = []
    func step(up: Bool, fine: Bool) -> HUDState? {
        steps.append(up)
        return HUDState(kind: .brightness, level: up ? 0.6 : 0.4)
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
}
```

- [ ] **Step 2: Run the tests and confirm that they fail.**

Run: `scripts/test.sh -only-testing:NotchyTests/QuickControlsTests`
Expected: FAIL with compile errors, because `VolumeStepping`, `QuickControls`, `perform` and the other new names do not exist yet.

- [ ] **Step 3: Add the logger category.** In `Notchy/App/Log.swift`, add this after `bluetooth`:

```swift
    static let controls = Logger(subsystem: subsystem, category: "Controls")
```

- [ ] **Step 4: Extend the view model.** In `Notchy/Notch/NotchViewModel.swift`, add this after the `expandedHUD` property:

```swift
    /// Quick controls the row can use right now; the others are drawn dimmed.
    @Published var availableControls: Set<QuickControl> = []
```

Add this after `var mediaCommandHandler: ((MediaCommand) -> Void)?`:

```swift
    var controlHandler: ((QuickControl) -> Void)?
```

Add this after `send(_:)`:

```swift
    func perform(_ control: QuickControl) {
        controlHandler?(control)
    }
```

- [ ] **Step 5: Implement the controls.** Create `Notchy/Modules/Controls/QuickControls.swift`:

```swift
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
```

Create `Notchy/Modules/Controls/ScreenLocker.swift`:

```swift
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
```

- [ ] **Step 6: Run the tests and confirm that they pass.**

Run: `scripts/test.sh -only-testing:NotchyTests/QuickControlsTests`
Expected: exit status 0.

- [ ] **Step 7: Commit.**

```bash
git add Notchy/Modules/Controls Notchy/App/Log.swift Notchy/Notch/NotchViewModel.swift NotchyTests/QuickControlsTests.swift
git commit -m "feat: add quick controls for brightness, volume and screen lock

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

### Task 2: Control row in the expanded island

**Files:**
- Create: `Notchy/Modules/Controls/QuickControlsView.swift`
- Modify:
  - `Notchy/Notch/NotchLayout.swift`
  - `Notchy/Notch/NotchView.swift` (`NotchView` and `ExpandedContentView`)
  - `Notchy/Notch/NotchPanelController.swift` (`updateHover`)
  - `Notchy/App/AppCoordinator.swift` (`start()`)
  - `docs/superpowers/specs/2026-09-23-notchy-design.md:70`
  - `README.md`
- Test: `NotchyTests/NotchGeometryTests.swift`
- Temporary, never committed: `NotchyTests/ExpandedSnapshotTests.swift`

**Interfaces:**
- Consumes from Task 1: `QuickControl`, `NotchViewModel.availableControls`, `NotchViewModel.perform(_:)`, `QuickControls`, `ScreenLocker`
- Produces:
  - `NotchLayout.islandSize(for:isMediaPlaying:hasMedia:notch:)`
  - `NotchLayout.expandedRowHeight`
  - `QuickControlsView(available:onControl:)`

- [ ] **Step 1: Write the failing tests.** In `NotchyTests/NotchGeometryTests.swift`, add `hasMedia: false` to every existing `islandSize` call:

```bash
sed -i '' -E 's/isMediaPlaying: (false|true), notch: notch\)/isMediaPlaying: \1, hasMedia: false, notch: notch)/g' NotchyTests/NotchGeometryTests.swift
```

In `testIslandSizes`, after the expanded line, add:

```swift
        XCTAssertEqual(NotchLayout.islandSize(for: .expanded, isMediaPlaying: false, hasMedia: true, notch: notch), CGSize(width: 472, height: 116))
```

Change the panel expectation in `testPanelSizeFitsExpandedIslandWithMargin` to:

```swift
        XCTAssertEqual(NotchLayout.panelSize(notch: notch), CGSize(width: 520, height: 140))
```

- [ ] **Step 2: Run the tests and confirm that they fail.**

Run: `scripts/test.sh -only-testing:NotchyTests/NotchGeometryTests`
Expected: FAIL with a compile error, because `islandSize` has no `hasMedia` argument yet.

- [ ] **Step 3: Update the layout.** In `Notchy/Notch/NotchLayout.swift`, add this after `expandedExtraHeight`:

```swift
    /// Extra height for the media row under the control row.
    static let expandedRowHeight: CGFloat = 36
```

Change the signature of `islandSize` and its `.expanded` case:

```swift
    static func islandSize(for state: NotchState, isMediaPlaying: Bool, hasMedia: Bool, notch: CGSize) -> CGSize {
```

```swift
        case .expanded:
            body = CGSize(width: max(notch.width + 2 * expandedSideWidth, expandedMinWidth),
                          height: notch.height + expandedExtraHeight + (hasMedia ? expandedRowHeight : 0))
```

In `panelSize`, use the tallest island:

```swift
        let expanded = islandSize(for: .expanded, isMediaPlaying: false, hasMedia: true, notch: notch)
```

In `Notchy/Notch/NotchPanelController.swift` `updateHover()`, pass the new argument:

```swift
        let island = NotchLayout.islandSize(for: viewModel.state,
                                            isMediaPlaying: viewModel.media?.isPlaying == true,
                                            hasMedia: viewModel.media != nil,
                                            notch: notchSize)
```

- [ ] **Step 4: Add the row view.** Create `Notchy/Modules/Controls/QuickControlsView.swift`:

```swift
import SwiftUI

/// The control row that is always at the top of the expanded island.
struct QuickControlsView: View {
    let available: Set<QuickControl>
    let onControl: (QuickControl) -> Void

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 2) {
                button("sun.min.fill", .brightnessDown)
                button("sun.max.fill", .brightnessUp)
            }
            HStack(spacing: 2) {
                button("speaker.wave.1.fill", .volumeDown)
                button("speaker.wave.3.fill", .volumeUp)
            }
            button("lock.fill", .lockScreen)
        }
    }

    private func button(_ symbol: String, _ control: QuickControl) -> some View {
        let isAvailable = available.contains(control)
        return Button { onControl(control) } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.3)
    }
}
```

- [ ] **Step 5: Show the rows.** Make these changes in `Notchy/Notch/NotchView.swift`.

In `NotchView`, add this after `isMediaPlaying`:

```swift
    private var hasMedia: Bool { viewModel.media != nil }
```

Then update `islandSize` to pass the new argument:

```swift
        NotchLayout.islandSize(for: viewModel.state, isMediaPlaying: isMediaPlaying, hasMedia: hasMedia, notch: notchSize)
```

After the existing `.animation(..., value: isMediaPlaying)` line, add:

```swift
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: hasMedia)
```

In `ExpandedContentView`, replace the second `Group { ... }`, the one with the media view or the "Şu an çalan bir şey yok" text, and keep its modifiers:

```swift
            VStack(spacing: 8) {
                QuickControlsView(available: viewModel.availableControls) { viewModel.perform($0) }
                if let media = viewModel.media {
                    MediaExpandedView(media: media) { viewModel.send($0) }
                }
            }
            .padding(.horizontal, NotchLayout.earRadius + 20)
            .frame(maxHeight: .infinity)
```

- [ ] **Step 6: Start the controls with the app.** In `Notchy/App/AppCoordinator.swift`, add this property next to `menuBar`:

```swift
    private var quickControls: QuickControls?
```

In `start()`, add this right after `panelController.start()`:

```swift
        quickControls = QuickControls(viewModel: viewModel, volume: VolumeController(),
                                      brightness: BrightnessController(), locker: ScreenLocker())
        quickControls?.start()
```

- [ ] **Step 7: Run the geometry tests and the full suite.**

Run: `scripts/test.sh`
Expected: exit status 0.

- [ ] **Step 8: Check the result visually (temporary).** Create `NotchyTests/ExpandedSnapshotTests.swift`:

```swift
import AppKit
import SwiftUI
import XCTest
@testable import Notchy

/// TEMPORARY: renders the expanded island to PNGs for a visual check. Do not commit.
@MainActor
final class ExpandedSnapshotTests: XCTestCase {
    func testRenderExpandedIsland() throws {
        let outDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/snapshots")
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let notch = CGSize(width: 200, height: 32)
        let song = MediaState(title: "Kuzu Kuzu", artist: "Tarkan", isPlaying: true, bundleIdentifier: nil)
        let all = Set(QuickControl.allCases)
        let noBrightness = all.subtracting([.brightnessDown, .brightnessUp])
        let cases: [(name: String, media: MediaState?, available: Set<QuickControl>, hud: HUDState?)] = [
            ("1-controls-only", nil, all, nil),
            ("2-with-media", song, all, nil),
            ("3-no-brightness", song, noBrightness, nil),
            ("4-hud", song, all, HUDState(kind: .brightness, level: 0.6)),
        ]
        for item in cases {
            let scheduler = ManualScheduler()
            let vm = NotchViewModel(scheduler: scheduler)
            vm.updateMedia(item.media)
            vm.availableControls = item.available
            vm.hoverChanged(true)
            scheduler.advance(by: vm.configuration.hoverDelay)
            if let hud = item.hud { vm.present(.hud(hud)) }
            let panel = NotchLayout.panelSize(notch: notch)
            let renderer = ImageRenderer(content: NotchView(viewModel: vm, notchSize: notch, isVirtualNotch: false)
                .frame(width: panel.width, height: panel.height)
                .background(Color(white: 0.8)))
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.cgImage)
            let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: outDir.appendingPathComponent("\(item.name).png"))
        }
    }
}
```

Run: `scripts/test.sh -only-testing:NotchyTests/ExpandedSnapshotTests`. Then open the PNGs in `build/snapshots/` and check:
- `1-controls-only`: the five buttons are centered right under the notch, in three groups, and the island is short.
- `2-with-media`: the control row is on top, the media row sits under it, and the island is taller.
- `3-no-brightness`: the two sun buttons are dimmed and still in the same place.
- `4-hud`: the sun icon and the level bar are in the strip beside the notch.

If a check fails, fix the view and run again. Then delete the temporary files: `rm NotchyTests/ExpandedSnapshotTests.swift && rm -rf build/snapshots`.

- [ ] **Step 9: Update the docs.** In `docs/superpowers/specs/2026-09-23-notchy-design.md`, line 70. Before:

```
- **expanded:** Hover ile açılır (gecikme ayarlanabilir, varsayılan 0.1 sn). Medya bilgisi ve kontroller burada.
```

After:

```
- **expanded:** Hover ile açılır (gecikme ayarlanabilir, varsayılan 0.1 sn). Üstte her zaman hızlı kontroller (parlaklık, ses, ekran kilidi; bkz. [2026-09-23-quick-controls-design.md](2026-09-23-quick-controls-design.md)), medya varsa altında medya satırı.
```

In `README.md`, add this bullet after the media bullet under `## Özellikler (v1)`:

```
- Hızlı kontroller: açık adada her zaman parlaklık ve ses düğmeleri, ekranı kilitleme
```

- [ ] **Step 10: Run the full suite and commit.**

Run: `scripts/test.sh`
Expected: exit status 0.

```bash
git add Notchy/Modules/Controls/QuickControlsView.swift Notchy/Notch/NotchLayout.swift Notchy/Notch/NotchView.swift \
  Notchy/Notch/NotchPanelController.swift Notchy/App/AppCoordinator.swift NotchyTests/NotchGeometryTests.swift \
  docs/superpowers/specs/2026-09-23-notchy-design.md README.md
git commit -m "feat: show the quick controls row in the expanded island

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

Afterwards the user checks it by hand: try the buttons with the island on the MacBook and on A32, and try the lock.
