# Countdown Timer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start a countdown from the island by typing minutes, show the remaining time small, and play a sound and show a notification when time is up.

**Architecture:**
- **Countdown state:** The state lives in `NotchViewModel`, next to the state machine that already exists. The view model gets an injected clock (`now`) so tests control time. The countdown uses one scheduled action at its end date; there is no polling.
- **Sizing:** A new `IslandContent` value collects everything besides the state that sizes the island, and `NotchLayout` sizes the island from it.
- **Keyboard:** The panel takes keyboard focus only while the minutes field is open.

**Tech Stack:** Swift (Swift 5 mode), SwiftUI + AppKit, XCTest.

**Spec:** `docs/superpowers/specs/2026-09-23-countdown-timer-design.md`

## Global Constraints

- Deployment target macOS 14.0. No new dependencies and no polling timers.
- Minutes must be whole numbers from 1 to 999; other values are ignored. Enter starts the countdown, Esc closes the field.
- Remaining time format is `m:ss`, or `h:mm:ss` from one hour up. It is 13 pt in the expanded row and 12 pt, orange, in the closed island.
- The timer-done peek (`PeekContent.timerDone`) lasts **5 s**. Priority order: HUD > timer > Bluetooth > battery > media.
- While the minutes field is open, the island does not collapse on hover exit.
- The done sound is `NSSound(named: "Glass")`.
- User-facing strings are Turkish: "dk", "Süre doldu".
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- Test command: `scripts/test.sh`, optionally with `-only-testing:NotchyTests/<Class>`. Exit status 0 means success.

---

### Task 1: Countdown state machine

**Files:**
- Create: `Notchy/Modules/Timer/Countdown.swift`
- Modify:
  - `Notchy/Activities/Activity.swift`
  - `Notchy/Notch/NotchLayout.swift` (add the `IslandContent` struct only)
  - `Notchy/Notch/NotchViewModel.swift`
- Test: `NotchyTests/CountdownTests.swift` (create)

**Interfaces:**
- Produces:
  - `enum CountdownState: Equatable { running(endDate: Date), paused(remaining: TimeInterval) }` with `isPaused`
  - `CountdownFormat.string(from:)`
  - `PeekContent.timerDone`, `ActivityPriority.timer`
  - `struct IslandContent: Equatable { isMediaPlaying, hasMedia, hasCountdown, isEditingCountdown; expandedRows }`
  - on `NotchViewModel`:
    - `init(scheduler:now:)`
    - `countdown` and `isEditingCountdown`, both published
    - `toggleCountdownEntry()`, `cancelCountdownEntry()`, `startCountdown(minutes:)`, `pauseCountdown()`, `resumeCountdown()`, `cancelCountdown()`
    - `onCountdownFinished`, `islandContent`
  - `NotchConfiguration.timerDoneDuration`

- [ ] **Step 1: Write the failing tests.** Create `NotchyTests/CountdownTests.swift`:

```swift
import XCTest
@testable import Notchy

@MainActor
final class CountdownTests: XCTestCase {
    private var scheduler: ManualScheduler!
    private var vm: NotchViewModel!
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    override func setUp() async throws {
        let scheduler = ManualScheduler()
        let start = start
        self.scheduler = scheduler
        vm = NotchViewModel(scheduler: scheduler, now: { start.addingTimeInterval(scheduler.now) })
    }

    private func expand() {
        vm.hoverChanged(true)
        scheduler.advance(by: vm.configuration.hoverDelay)
        XCTAssertEqual(vm.state, .expanded)
    }

    func testTimerButtonTogglesTheMinutesField() {
        vm.toggleCountdownEntry()
        XCTAssertTrue(vm.isEditingCountdown)
        vm.toggleCountdownEntry()
        XCTAssertFalse(vm.isEditingCountdown)
    }

    func testTimerButtonDoesNothingWhileACountdownExists() {
        vm.startCountdown(minutes: 5)
        vm.toggleCountdownEntry()
        XCTAssertFalse(vm.isEditingCountdown)
    }

    func testStartingRunsUntilTheEndThenShowsTheDonePeek() {
        var finished = 0
        vm.onCountdownFinished = { finished += 1 }
        vm.toggleCountdownEntry()
        vm.startCountdown(minutes: 1)
        XCTAssertFalse(vm.isEditingCountdown)
        XCTAssertEqual(vm.countdown, .running(endDate: start.addingTimeInterval(60)))
        scheduler.advance(by: 59)
        XCTAssertNotNil(vm.countdown)
        scheduler.advance(by: 1)
        XCTAssertNil(vm.countdown)
        XCTAssertEqual(vm.state, .peek(.timerDone))
        XCTAssertEqual(finished, 1)
    }

    func testDonePeekStaysFiveSeconds() {
        vm.startCountdown(minutes: 1)
        scheduler.advance(by: 60)
        scheduler.advance(by: 4.9)
        XCTAssertEqual(vm.state, .peek(.timerDone))
        scheduler.advance(by: 0.1)
        XCTAssertEqual(vm.state, .closed)
    }

    func testMinutesOutsideTheRangeAreIgnored() {
        vm.toggleCountdownEntry()
        vm.startCountdown(minutes: 0)
        vm.startCountdown(minutes: 1000)
        XCTAssertNil(vm.countdown)
        XCTAssertTrue(vm.isEditingCountdown)
    }

    func testPauseAndResumeKeepTheRemainingTime() {
        vm.startCountdown(minutes: 1)
        scheduler.advance(by: 20)
        vm.pauseCountdown()
        XCTAssertEqual(vm.countdown, .paused(remaining: 40))
        scheduler.advance(by: 100)
        XCTAssertEqual(vm.countdown, .paused(remaining: 40), "a paused countdown must not finish")
        vm.resumeCountdown()
        XCTAssertEqual(vm.countdown, .running(endDate: start.addingTimeInterval(160)))
        scheduler.advance(by: 40)
        XCTAssertNil(vm.countdown)
    }

    func testCancelStopsTheCountdown() {
        var finished = 0
        vm.onCountdownFinished = { finished += 1 }
        vm.startCountdown(minutes: 1)
        vm.cancelCountdown()
        scheduler.advance(by: 120)
        XCTAssertNil(vm.countdown)
        XCTAssertEqual(finished, 0)
        XCTAssertEqual(vm.state, .closed)
    }

    func testIslandStaysOpenWhileEnteringMinutes() {
        expand()
        vm.toggleCountdownEntry()
        vm.hoverChanged(false)
        scheduler.advance(by: 10)
        XCTAssertEqual(vm.state, .expanded)
        vm.cancelCountdownEntry()
        scheduler.advance(by: vm.configuration.collapseDelay)
        XCTAssertEqual(vm.state, .closed)
    }

    func testIslandContentReportsTheCountdown() {
        vm.toggleCountdownEntry()
        XCTAssertEqual(vm.islandContent, IslandContent(isEditingCountdown: true))
        vm.startCountdown(minutes: 5)
        XCTAssertEqual(vm.islandContent, IslandContent(hasCountdown: true))
    }

    func testFormat() {
        XCTAssertEqual(CountdownFormat.string(from: 59), "0:59")
        XCTAssertEqual(CountdownFormat.string(from: 299.2), "5:00")
        XCTAssertEqual(CountdownFormat.string(from: 3723), "1:02:03")
    }
}
```

- [ ] **Step 2: Run the tests and confirm that they fail.**

Run: `scripts/test.sh -only-testing:NotchyTests/CountdownTests`
Expected: FAIL with compile errors, because `now:`, `countdown`, `IslandContent` and the other new names do not exist yet.

- [ ] **Step 3: Add the countdown types.** Create `Notchy/Modules/Timer/Countdown.swift`:

```swift
import Foundation

/// A countdown started from the island.
enum CountdownState: Equatable {
    case running(endDate: Date)
    case paused(remaining: TimeInterval)

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}

enum CountdownFormat {
    /// `m:ss`, or `h:mm:ss` from one hour up. Partial seconds round up, so 0.4 s shows 0:01.
    static func string(from seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let hours = total / 3600, minutes = (total % 3600) / 60, secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
```

- [ ] **Step 4: Add the done peek.** In `Notchy/Activities/Activity.swift`:
- Make the priorities `case media = 0, battery = 1, bluetooth = 2, timer = 3, hud = 4`.
- Add `case timerDone` to `PeekContent`.
- Add `case .timerDone: return .timer` to `priority`.

- [ ] **Step 5: Add `IslandContent`.** In `Notchy/Notch/NotchLayout.swift`, add this above `enum NotchLayout`. Task 2 makes the layout use it.

```swift
/// What the island shows besides its state; drives its size.
struct IslandContent: Equatable {
    var isMediaPlaying = false
    var hasMedia = false
    var hasCountdown = false
    var isEditingCountdown = false

    /// Rows under the notch while expanded: controls, then countdown, then media.
    var expandedRows: Int {
        1 + (hasCountdown || isEditingCountdown ? 1 : 0) + (hasMedia ? 1 : 0)
    }
}
```

- [ ] **Step 6: Add the countdown to the view model.** Make these changes in `Notchy/Notch/NotchViewModel.swift`.

In `NotchConfiguration`, add:

```swift
    var timerDoneDuration: TimeInterval = 5.0
```

After `availableControls`, add:

```swift
    /// The running or paused countdown, if any.
    @Published private(set) var countdown: CountdownState?
    /// True while the minutes field is open; keeps the island expanded and takes the keyboard.
    @Published private(set) var isEditingCountdown = false
```

After `controlHandler`, add:

```swift
    /// Plays the done sound; set by the app so the view model stays free of AppKit.
    var onCountdownFinished: (() -> Void)?
```

Next to the other private properties, add:

```swift
    private let now: () -> Date
    private var countdownToken: SchedulerToken?
```

Replace `init`:

```swift
    init(scheduler: Scheduler, now: @escaping () -> Date = Date.init) {
        self.scheduler = scheduler
        self.now = now
    }

    /// What the island shows besides its state; drives its size.
    var islandContent: IslandContent {
        IslandContent(isMediaPlaying: media?.isPlaying == true, hasMedia: media != nil,
                      hasCountdown: countdown != nil, isEditingCountdown: isEditingCountdown)
    }
```

In `hoverChanged`, keep the island open while editing. Change the collapse branch to:

```swift
        } else if state == .expanded, !isEditingCountdown {
```

In `showPeek`, replace the duration line:

```swift
        let duration: TimeInterval
        switch content {
        case .hud: duration = configuration.hudDuration
        case .timerDone: duration = configuration.timerDoneDuration
        case .battery, .bluetooth: duration = configuration.peekDuration
        }
```

In `collapse()`, add `isEditingCountdown = false` before `state = .closed`.

At the end of the class, add:

```swift
    // MARK: - Countdown

    /// The timer button: opens or closes the minutes field while no countdown exists.
    func toggleCountdownEntry() {
        guard countdown == nil else { return }
        if isEditingCountdown {
            cancelCountdownEntry()
        } else {
            isEditingCountdown = true
        }
    }

    func cancelCountdownEntry() {
        guard isEditingCountdown else { return }
        isEditingCountdown = false
        collapseIfMouseLeft()
    }

    /// Starts a countdown from the minutes field; values outside 1...999 are ignored.
    func startCountdown(minutes: Int) {
        guard (1...999).contains(minutes) else { return }
        isEditingCountdown = false
        run(for: TimeInterval(minutes) * 60)
        collapseIfMouseLeft()
    }

    func pauseCountdown() {
        guard case .running(let endDate) = countdown else { return }
        countdownToken?.cancel()
        countdownToken = nil
        countdown = .paused(remaining: max(0, endDate.timeIntervalSince(now())))
    }

    func resumeCountdown() {
        guard case .paused(let remaining) = countdown else { return }
        run(for: remaining)
    }

    func cancelCountdown() {
        countdownToken?.cancel()
        countdownToken = nil
        countdown = nil
    }

    private func run(for duration: TimeInterval) {
        countdownToken?.cancel()
        countdown = .running(endDate: now().addingTimeInterval(duration))
        countdownToken = scheduler.schedule(after: duration) { [weak self] in self?.countdownFinished() }
    }

    private func countdownFinished() {
        countdownToken = nil
        countdown = nil
        present(.timerDone)
        onCountdownFinished?()
    }

    /// Editing kept the island open after the mouse left; close it the normal way now.
    private func collapseIfMouseLeft() {
        guard state == .expanded, !isHovering else { return }
        hoverToken?.cancel()
        hoverToken = scheduler.schedule(after: configuration.collapseDelay) { [weak self] in self?.collapse() }
    }
```

The `PeekContentView` switch in `NotchView.swift` must stay exhaustive. Add a temporary `case .timerDone: EmptyView()`; Task 3 replaces it.

- [ ] **Step 7: Run the tests and confirm that they pass.**

Run: `scripts/test.sh -only-testing:NotchyTests/CountdownTests`
Expected: exit status 0.

- [ ] **Step 8: Commit.**

```bash
git add Notchy/Modules/Timer Notchy/Activities/Activity.swift Notchy/Notch/NotchLayout.swift \
  Notchy/Notch/NotchViewModel.swift Notchy/Notch/NotchView.swift NotchyTests/CountdownTests.swift
git commit -m "feat: add the countdown state machine

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

### Task 2: Size the island from `IslandContent`

**Files:**
- Modify: `Notchy/Notch/NotchLayout.swift`, `Notchy/Notch/NotchView.swift`, `Notchy/Notch/NotchPanelController.swift`
- Test: `NotchyTests/NotchGeometryTests.swift`

**Interfaces:**
- Produces:
  - `NotchLayout.islandSize(for:content:notch:)`
  - `NotchLayout.isHidden(state:content:isVirtualNotch:)`
  - `NotchLayout.countdownSideWidth`

- [ ] **Step 1: Write the failing tests.** In `NotchyTests/NotchGeometryTests.swift`, replace `testIslandSizes`, `testPanelSizeFitsExpandedIslandWithMargin` and `testIdleIslandIsHiddenOnlyOnAVirtualNotch` with:

```swift
    func testIslandSizes() {
        func size(_ state: NotchState, _ content: IslandContent) -> CGSize {
            NotchLayout.islandSize(for: state, content: content, notch: notch)
        }
        XCTAssertEqual(size(.closed, IslandContent()), CGSize(width: 212, height: 32))
        XCTAssertEqual(size(.closed, IslandContent(isMediaPlaying: true, hasMedia: true)), CGSize(width: 276, height: 32))
        XCTAssertEqual(size(.closed, IslandContent(hasCountdown: true)), CGSize(width: 364, height: 32))
        XCTAssertEqual(size(.peek(Fixtures.pluggedIn), IslandContent()), CGSize(width: 432, height: 32))
        XCTAssertEqual(size(.expanded, IslandContent()), CGSize(width: 472, height: 80))
        XCTAssertEqual(size(.expanded, IslandContent(hasMedia: true)), CGSize(width: 472, height: 116))
        XCTAssertEqual(size(.expanded, IslandContent(isEditingCountdown: true)), CGSize(width: 472, height: 116))
        XCTAssertEqual(size(.expanded, IslandContent(hasMedia: true, hasCountdown: true)), CGSize(width: 472, height: 152))
    }

    func testPanelSizeFitsExpandedIslandWithMargin() {
        XCTAssertEqual(NotchLayout.panelSize(notch: notch), CGSize(width: 520, height: 176))
    }

    func testIdleIslandIsHiddenOnlyOnAVirtualNotch() {
        func hidden(_ state: NotchState, _ content: IslandContent, virtual: Bool = true) -> Bool {
            NotchLayout.isHidden(state: state, content: content, isVirtualNotch: virtual)
        }
        XCTAssertTrue(hidden(.closed, IslandContent()))
        XCTAssertFalse(hidden(.closed, IslandContent(isMediaPlaying: true, hasMedia: true)))
        XCTAssertFalse(hidden(.closed, IslandContent(hasCountdown: true)))
        XCTAssertFalse(hidden(.expanded, IslandContent()))
        XCTAssertFalse(hidden(.peek(Fixtures.pluggedIn), IslandContent()))
        XCTAssertFalse(hidden(.closed, IslandContent(), virtual: false))
    }
```

- [ ] **Step 2: Run the tests and confirm that they fail.**

Run: `scripts/test.sh -only-testing:NotchyTests/NotchGeometryTests`
Expected: FAIL with compile errors, because `islandSize(for:content:notch:)` does not exist yet.

- [ ] **Step 3: Update the layout.** In `Notchy/Notch/NotchLayout.swift`, first add:

```swift
    static let countdownSideWidth: CGFloat = 76
```

Change the doc comment of `expandedRowHeight` to `/// Extra height for each row under the control row (countdown, media).`.

Then replace `islandSize`, `panelSize` and `isHidden` with:

```swift
    static func islandSize(for state: NotchState, content: IslandContent, notch: CGSize) -> CGSize {
        let body: CGSize
        switch state {
        case .closed:
            let side = content.hasCountdown ? countdownSideWidth
                : content.isMediaPlaying ? mediaIndicatorWidth : 0
            body = CGSize(width: notch.width + 2 * side, height: notch.height)
        case .peek:
            body = CGSize(width: notch.width + 2 * peekSideWidth, height: notch.height)
        case .expanded:
            body = CGSize(width: max(notch.width + 2 * expandedSideWidth, expandedMinWidth),
                          height: notch.height + expandedExtraHeight
                              + CGFloat(content.expandedRows - 1) * expandedRowHeight)
        }
        return CGSize(width: body.width + 2 * earRadius, height: body.height)
    }

    static func panelSize(notch: CGSize) -> CGSize {
        let tallest = IslandContent(isMediaPlaying: true, hasMedia: true, hasCountdown: true)
        let expanded = islandSize(for: .expanded, content: tallest, notch: notch)
        return CGSize(width: expanded.width + 2 * panelMargin, height: expanded.height + panelMargin)
    }
```

```swift
    /// On a screen without a physical notch the idle island is not drawn; its area still detects hover.
    static func isHidden(state: NotchState, content: IslandContent, isVirtualNotch: Bool) -> Bool {
        isVirtualNotch && state == .closed && !content.isMediaPlaying && !content.hasCountdown
    }
```

- [ ] **Step 4: Update the callers.** In `NotchView`, replace the `isMediaPlaying`, `hasMedia`, `islandSize` and `isHidden` properties with:

```swift
    private var islandContent: IslandContent { viewModel.islandContent }

    private var islandSize: CGSize {
        NotchLayout.islandSize(for: viewModel.state, content: islandContent, notch: notchSize)
    }

    private var isHidden: Bool {
        NotchLayout.isHidden(state: viewModel.state, content: islandContent, isVirtualNotch: isVirtualNotch)
    }
```

Replace the two `.animation(...)` lines for `isMediaPlaying` and `hasMedia` with one line:

```swift
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: islandContent)
```

In `content`, change the closed case to `ClosedContentView(isMediaPlaying: islandContent.isMediaPlaying)`.

In `NotchPanelController.updateHover()`, use:

```swift
        let island = NotchLayout.islandSize(for: viewModel.state, content: viewModel.islandContent, notch: notchSize)
```

- [ ] **Step 5: Run the full suite and confirm that it passes.**

Run: `scripts/test.sh`
Expected: exit status 0.

- [ ] **Step 6: Commit.**

```bash
git add Notchy/Notch/NotchLayout.swift Notchy/Notch/NotchView.swift Notchy/Notch/NotchPanelController.swift NotchyTests/NotchGeometryTests.swift
git commit -m "refactor: size the island from IslandContent

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

### Task 3: Timer views, keyboard focus and sound

**Files:**
- Create: `Notchy/Modules/Timer/TimerViews.swift`
- Modify:
  - `Notchy/Modules/Controls/QuickControlsView.swift`
  - `Notchy/Notch/NotchView.swift`
  - `Notchy/Notch/NotchPanel.swift`
  - `Notchy/Notch/NotchPanelController.swift`
  - `Notchy/App/AppCoordinator.swift`
  - `docs/superpowers/specs/2026-09-23-notchy-design.md:74`
  - `README.md`
- Temporary, never committed: `NotchyTests/ExpandedSnapshotTests.swift`

**Interfaces:**
- Consumes from Tasks 1–2: all names produced there
- Produces:
  - `QuickControlsView(available:isTimerActive:onControl:onTimer:)`
  - `CountdownText`, `CountdownRowView`, `TimerDonePeekView`
  - `NotchPanel.acceptsKeyboard`

- [ ] **Step 1: Add the timer views.** Create `Notchy/Modules/Timer/TimerViews.swift`:

```swift
import SwiftUI

/// Remaining time: a live countdown while running, frozen while paused.
struct CountdownText: View {
    let countdown: CountdownState

    var body: some View {
        switch countdown {
        case .running(let endDate): Text(endDate, style: .timer)
        case .paused(let remaining): Text(CountdownFormat.string(from: remaining))
        }
    }
}

/// The timer row under the controls: the minutes field, or the running countdown.
struct CountdownRowView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var minutes = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if let countdown = viewModel.countdown {
                CountdownText(countdown: countdown)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                button(countdown.isPaused ? "play.fill" : "pause.fill") {
                    countdown.isPaused ? viewModel.resumeCountdown() : viewModel.pauseCountdown()
                }
                button("xmark") { viewModel.cancelCountdown() }
            } else {
                TextField("dk", text: $minutes)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(width: 56, height: 22)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    .focused($isFieldFocused)
                    .onSubmit { viewModel.startCountdown(minutes: Int(minutes) ?? 0) }
                    .onExitCommand { viewModel.cancelCountdownEntry() }
                    .onAppear {
                        minutes = ""
                        // The panel becomes key in the same update; focus once it is.
                        DispatchQueue.main.async { isFieldFocused = true }
                    }
            }
        }
        .frame(height: 28)
    }

    private func button(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct TimerDonePeekView: View {
    let notchWidth: CGFloat

    var body: some View {
        PeekLayout(notchWidth: notchWidth) {
            Text("Süre doldu")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        } right: {
            Image(systemName: "bell.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange)
        }
    }
}
```

- [ ] **Step 2: Add the timer button.** In `QuickControlsView`:
- Add `let isTimerActive: Bool` after `available`.
- Add `let onTimer: () -> Void` after `onControl`.
- After `button("lock.fill", .lockScreen)`, add `timerButton`.
- Add this property:

```swift
    private var timerButton: some View {
        Button(action: onTimer) {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isTimerActive ? Color.orange : Color.white)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
```

- [ ] **Step 3: Show the timer in the island.** In `Notchy/Notch/NotchView.swift`:
- In the `content` closed case, use `ClosedContentView(isMediaPlaying: islandContent.isMediaPlaying, countdown: viewModel.countdown)`.
- In `PeekContentView`, replace the temporary case with `case .timerDone: TimerDonePeekView(notchWidth: notchWidth)`.

Replace `ClosedContentView` with:

```swift
struct ClosedContentView: View {
    let isMediaPlaying: Bool
    let countdown: CountdownState?

    var body: some View {
        HStack {
            if let countdown {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    CountdownText(countdown: countdown)
                }
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.orange)
                .padding(.leading, NotchLayout.earRadius + 6)
            }
            Spacer()
            if isMediaPlaying {
                EqualizerView().padding(.trailing, NotchLayout.earRadius + 10)
            }
        }
        .frame(maxHeight: .infinity)
    }
}
```

In `ExpandedContentView`, replace the `VStack(spacing: 8) { ... }` contents with:

```swift
                QuickControlsView(available: viewModel.availableControls,
                                  isTimerActive: viewModel.countdown != nil,
                                  onControl: { viewModel.perform($0) },
                                  onTimer: { viewModel.toggleCountdownEntry() })
                if viewModel.countdown != nil || viewModel.isEditingCountdown {
                    CountdownRowView(viewModel: viewModel)
                }
                if let media = viewModel.media {
                    MediaExpandedView(media: media) { viewModel.send($0) }
                }
```

- [ ] **Step 4: Give the panel the keyboard while editing.** In `Notchy/Notch/NotchPanel.swift`, replace `override var canBecomeKey: Bool { false }` with:

```swift
    /// Only while the countdown's minutes field is open does the panel take the keyboard.
    var acceptsKeyboard = false

    override var canBecomeKey: Bool { acceptsKeyboard }
```

In `NotchPanelController.start()`, replace the `viewModel.$state.combineLatest(viewModel.$media)` subscription and its comment with:

```swift
        // A peek ending, the island collapsing or the countdown appearing can change the
        // click-capture region (via NotchLayout.islandSize) without any mouse movement, so a
        // stale `ignoresMouseEvents` must also be corrected on every view-model change.
        // `updateHover()` is idempotent when hover state is unchanged, so this can't feedback loop.
        viewModel.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateHover() }
            .store(in: &cancellables)
        // The minutes field needs the keyboard; hand it back as soon as the field closes.
        viewModel.$isEditingCountdown
            .removeDuplicates()
            .sink { [weak self] editing in self?.setAcceptsKeyboard(editing) }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)
            .sink { [weak self] note in
                guard let self, let panel = self.panel, note.object as? NSWindow === panel else { return }
                self.viewModel.cancelCountdownEntry()
            }
            .store(in: &cancellables)
```

Add this method to `NotchPanelController`:

```swift
    private func setAcceptsKeyboard(_ accepts: Bool) {
        guard let panel else { return }
        panel.acceptsKeyboard = accepts
        if accepts {
            panel.makeKey()
        } else if panel.isKeyWindow {
            // Ordering out a key window makes macOS give the keyboard back to the active app.
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
    }
```

- [ ] **Step 5: Play the sound.** In `AppCoordinator.start()`, after `quickControls?.start()`, add:

```swift
        viewModel.onCountdownFinished = { NSSound(named: "Glass")?.play() }
```

- [ ] **Step 6: Run the full suite.**

Run: `scripts/test.sh`
Expected: exit status 0.

- [ ] **Step 7: Check the result visually (temporary).** Create `NotchyTests/ExpandedSnapshotTests.swift`. It uses the real clock, so `Text(.timer)` shows about 5:00.

```swift
import AppKit
import SwiftUI
import XCTest
@testable import Notchy

/// TEMPORARY: renders the island to PNGs for a visual check. Do not commit.
@MainActor
final class ExpandedSnapshotTests: XCTestCase {
    func testRenderTimer() throws {
        let outDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/snapshots")
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let notch = CGSize(width: 200, height: 32)
        let song = MediaState(title: "Kuzu Kuzu", artist: "Tarkan", isPlaying: true, bundleIdentifier: nil)
        let cases: [(name: String, expand: Bool, setUp: (NotchViewModel) -> Void)] = [
            ("1-entry", true, { $0.toggleCountdownEntry() }),
            ("2-running", true, { $0.updateMedia(song); $0.startCountdown(minutes: 5) }),
            ("3-paused", true, { $0.startCountdown(minutes: 5); $0.pauseCountdown() }),
            ("4-closed", false, { $0.updateMedia(song); $0.startCountdown(minutes: 5) }),
            ("5-done", false, { $0.present(.timerDone) }),
        ]
        for item in cases {
            let scheduler = ManualScheduler()
            let vm = NotchViewModel(scheduler: scheduler)
            vm.availableControls = Set(QuickControl.allCases)
            if item.expand {
                vm.hoverChanged(true)
                scheduler.advance(by: vm.configuration.hoverDelay)
            }
            item.setUp(vm)
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

Run: `scripts/test.sh -only-testing:NotchyTests/ExpandedSnapshotTests`. Then check the PNGs:
- `1-entry`: a small "dk" field sits under the controls, and the timer button is at the end of the controls.
- `2-running`: the rows are controls, then `5:00` with pause and × buttons, then media. The timer button is orange.
- `3-paused`: a play button replaces pause.
- `4-closed`: an orange timer icon and `5:00` show left of the notch, and the equalizer shows on the right.
- `5-done`: the peek reads "Süre doldu" with an orange bell.

Fix anything that does not match, then delete the temporary files: `rm NotchyTests/ExpandedSnapshotTests.swift && rm -rf build/snapshots`.

- [ ] **Step 8: Update the docs.** In `docs/superpowers/specs/2026-09-23-notchy-design.md`, line 74. Before:

```
- Öncelik: **HUD > Bluetooth > Pil > Medya**.
```

After:

```
- Öncelik: **HUD > Zamanlayıcı > Bluetooth > Pil > Medya** (zamanlayıcı: bkz. [2026-09-23-countdown-timer-design.md](2026-09-23-countdown-timer-design.md)).
```

In `README.md`, add this after the quick-controls bullet:

```
- Zamanlayıcı: açık adadan dakika girip geri sayım; kalan süre kapalı adada, bitince ses ve bildirim
```

- [ ] **Step 9: Run the full suite and commit.**

Run: `scripts/test.sh`
Expected: exit status 0.

```bash
git add Notchy/Modules/Timer/TimerViews.swift Notchy/Modules/Controls/QuickControlsView.swift Notchy/Notch/NotchView.swift \
  Notchy/Notch/NotchPanel.swift Notchy/Notch/NotchPanelController.swift Notchy/App/AppCoordinator.swift \
  docs/superpowers/specs/2026-09-23-notchy-design.md README.md
git commit -m "feat: add the countdown timer to the island

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

Afterwards the user checks it by hand:
- type minutes; the app in front must keep its focus while you type
- Esc
- click somewhere else
- pause/resume and cancel
- the sound and the notification
