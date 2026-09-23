# External Display Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the single island on whichever screen the mouse is on. Screens without a physical notch get a virtual notch, and on those screens the idle island is hidden.

**Architecture:**
- **Pure helpers in `NotchGeometry` and `NotchLayout`:**
  - `placement(...)`: returns the physical notch, or a virtual notch 185 pt wide and as tall as the menu bar.
  - `screenIndex(containing:in:)`: finds the screen that contains a point.
  - `isHidden(...)`: tells whether the idle island should be hidden.
- **`NotchPanelController` moves the one panel between screens.** It checks the screen under the mouse on every mouse move and on every state change. It does not move the panel while the island is expanded.
- **Modules run whenever a screen exists.** Before, they ran only when a notch existed.
- `NotchViewModel` does not change.

**Tech Stack:** Swift (Swift 5 mode), SwiftUI + AppKit, XCTest, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-09-23-external-display-design.md`

## Global Constraints

- Deployment target macOS 14.0 and no new dependencies. Do not add polling timers; use only the existing mouse-moved monitors, state subscriptions and screen notifications.
- Virtual notch: width **185 pt**. Height is the screen's menu bar height, `frame.maxY - visibleFrame.maxY`. If that is 0, use **24 pt**.
- The island is hidden only when the notch is virtual, the state is `closed` and no media is playing. While hidden, the island's area still detects hover.
- The island moves to the screen under the mouse. While it is `expanded` it does not move; it moves after it collapses.
- Screen availability is reported once at start, then only when it changes.
- User-facing strings are in Turkish.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- Test command: `scripts/test.sh`, optionally with `-only-testing:NotchyTests/<Class>`. Exit status 0 means success.

---

### Task 1: Virtual notch placement, screen lookup and idle-hiding rule

**Files:**
- Modify: `Notchy/Notch/NotchGeometry.swift`
- Modify: `Notchy/Notch/NotchLayout.swift`
- Test: `NotchyTests/NotchGeometryTests.swift`

**Interfaces:**
- Produces:
  - `struct NotchPlacement: Equatable { var size: CGSize; var isVirtual: Bool }`
  - `NotchGeometry.placement(screenWidth:safeAreaTop:leftAuxiliaryWidth:rightAuxiliaryWidth:menuBarHeight:) -> NotchPlacement`
  - `NotchGeometry.screenIndex(containing: CGPoint, in: [CGRect]) -> Int?`
  - `NotchLayout.isHidden(state: NotchState, isMediaPlaying: Bool, isVirtualNotch: Bool) -> Bool`

- [ ] **Step 1: Write the failing tests.** Add these methods to `NotchGeometryTests`, before its closing brace:

```swift
    func testPlacementUsesThePhysicalNotch() {
        let placement = NotchGeometry.placement(screenWidth: 1512, safeAreaTop: 32, leftAuxiliaryWidth: 663.5,
                                                rightAuxiliaryWidth: 663.5, menuBarHeight: 32)
        XCTAssertEqual(placement, NotchPlacement(size: CGSize(width: 185, height: 32), isVirtual: false))
    }

    func testPlacementUsesAVirtualNotchAsTallAsTheMenuBar() {
        let placement = NotchGeometry.placement(screenWidth: 2560, safeAreaTop: 0, leftAuxiliaryWidth: nil,
                                                rightAuxiliaryWidth: nil, menuBarHeight: 31)
        XCTAssertEqual(placement, NotchPlacement(size: CGSize(width: 185, height: 31), isVirtual: true))
    }

    func testVirtualNotchFallsBackTo24PointsWithoutAMenuBar() {
        let placement = NotchGeometry.placement(screenWidth: 2560, safeAreaTop: 0, leftAuxiliaryWidth: nil,
                                                rightAuxiliaryWidth: nil, menuBarHeight: 0)
        XCTAssertEqual(placement, NotchPlacement(size: CGSize(width: 185, height: 24), isVirtual: true))
    }

    func testScreenIndexFindsTheScreenUnderThePoint() {
        let frames = [CGRect(x: 0, y: 0, width: 2560, height: 1440),
                      CGRect(x: 2560, y: 211, width: 1512, height: 982)]
        XCTAssertEqual(NotchGeometry.screenIndex(containing: CGPoint(x: 100, y: 100), in: frames), 0)
        XCTAssertEqual(NotchGeometry.screenIndex(containing: CGPoint(x: 3000, y: 500), in: frames), 1)
        XCTAssertEqual(NotchGeometry.screenIndex(containing: CGPoint(x: 2560, y: 500), in: frames), 1)
        XCTAssertEqual(NotchGeometry.screenIndex(containing: CGPoint(x: 100, y: 1440), in: frames), 0, "top edge counts")
        XCTAssertNil(NotchGeometry.screenIndex(containing: CGPoint(x: 3000, y: 100), in: frames))
    }

    func testIdleIslandIsHiddenOnlyOnAVirtualNotch() {
        XCTAssertTrue(NotchLayout.isHidden(state: .closed, isMediaPlaying: false, isVirtualNotch: true))
        XCTAssertFalse(NotchLayout.isHidden(state: .closed, isMediaPlaying: true, isVirtualNotch: true))
        XCTAssertFalse(NotchLayout.isHidden(state: .expanded, isMediaPlaying: false, isVirtualNotch: true))
        XCTAssertFalse(NotchLayout.isHidden(state: .peek(Fixtures.pluggedIn), isMediaPlaying: false, isVirtualNotch: true))
        XCTAssertFalse(NotchLayout.isHidden(state: .closed, isMediaPlaying: false, isVirtualNotch: false))
    }
```

- [ ] **Step 2: Run the tests and confirm that they fail.**

Run: `scripts/test.sh -only-testing:NotchyTests/NotchGeometryTests`
Expected: FAIL with compile errors, because `NotchPlacement`, `placement`, `screenIndex` and `isHidden` do not exist yet.

- [ ] **Step 3: Implement the geometry helpers.** In `Notchy/Notch/NotchGeometry.swift`, add the struct above `enum NotchGeometry`:

```swift
/// Where the island sits on one screen: over the physical notch, or over a virtual notch
/// at the top center of a screen that has none.
struct NotchPlacement: Equatable {
    var size: CGSize
    var isVirtual: Bool
}
```

Then add the following inside `enum NotchGeometry`. Keep `notchSize` and `panelFrame` as they are.

```swift
    /// Virtual notch width, the same as the MacBook Pro notch.
    static let virtualNotchWidth: CGFloat = 185
    /// Virtual notch height when the screen shows no menu bar (auto-hidden, or none on that display).
    static let fallbackMenuBarHeight: CGFloat = 24

    /// The physical notch when the screen has one, otherwise a virtual notch as tall as the menu bar.
    static func placement(screenWidth: CGFloat, safeAreaTop: CGFloat,
                          leftAuxiliaryWidth: CGFloat?, rightAuxiliaryWidth: CGFloat?,
                          menuBarHeight: CGFloat) -> NotchPlacement {
        if let size = notchSize(screenWidth: screenWidth, safeAreaTop: safeAreaTop,
                                leftAuxiliaryWidth: leftAuxiliaryWidth, rightAuxiliaryWidth: rightAuxiliaryWidth) {
            return NotchPlacement(size: size, isVirtual: false)
        }
        let height = menuBarHeight > 0 ? menuBarHeight : fallbackMenuBarHeight
        return NotchPlacement(size: CGSize(width: virtualNotchWidth, height: height), isVirtual: true)
    }

    /// Index of the screen frame containing `point`. The top edge (y == maxY) counts as inside,
    /// because the mouse can sit on the very top pixel row.
    static func screenIndex(containing point: CGPoint, in frames: [CGRect]) -> Int? {
        frames.firstIndex { frame in
            point.x >= frame.minX && point.x < frame.maxX && point.y >= frame.minY && point.y <= frame.maxY
        }
    }
```

- [ ] **Step 4: Implement the hiding rule.** In `Notchy/Notch/NotchLayout.swift`, add this inside `enum NotchLayout`, after `islandRect`:

```swift
    /// On a screen without a physical notch the idle island is not drawn; its area still detects hover.
    static func isHidden(state: NotchState, isMediaPlaying: Bool, isVirtualNotch: Bool) -> Bool {
        isVirtualNotch && state == .closed && !isMediaPlaying
    }
```

- [ ] **Step 5: Run the tests and confirm that they pass.**

Run: `scripts/test.sh -only-testing:NotchyTests/NotchGeometryTests`
Expected: exit status 0.

- [ ] **Step 6: Commit.**

```bash
git add Notchy/Notch/NotchGeometry.swift Notchy/Notch/NotchLayout.swift NotchyTests/NotchGeometryTests.swift
git commit -m "feat: add virtual notch placement, screen lookup and idle-hiding rule

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

### Task 2: Run modules whenever a screen exists

**Files:**
- Modify: `Notchy/App/AppCoordinator.swift`: `start()` at lines 31-38, and `ModuleLifecycle` at lines 93-97, 122-126 and 131
- Modify: `Notchy/Settings/ModuleStatus.swift:8`
- Modify: `Notchy/App/MenuBarController.swift`: lines 6, 17-19 and 27-29
- Modify: `Notchy/Settings/SettingsView.swift:10-13`
- Modify: `Notchy/Notch/NotchPanelController.swift`: rename the callback only
- Test: `NotchyTests/AppCoordinatorTests.swift`

**Interfaces:**
- Produces:
  - `ModuleLifecycle.setHasScreen(_ hasScreen: Bool)`, which replaces `setHasNotch`
  - `ModuleStatus.hasScreen`, which replaces `hasNotch`
  - `NotchPanelController.onScreenAvailabilityChange: ((Bool) -> Void)?`, which replaces `onNotchAvailabilityChange`

- [ ] **Step 1: Update the tests to the new names.**

```bash
sed -i '' -e 's/setHasNotch/setHasScreen/g' \
  -e 's/testNoModuleStartsWithoutANotch/testNoModuleStartsWithoutAScreen/' \
  -e 's/testModulesStartWhenNotchAppearsAndStopWhenItDisappears/testModulesStartWhenAScreenAppearsAndStopWhenItDisappears/' \
  -e 's/nothing may run without a notch\./nothing may run without a screen./' \
  -e 's/must not run without a notch/must not run without a screen/' \
  -e 's/once the notch is gone/once the screen is gone/' NotchyTests/AppCoordinatorTests.swift
```

- [ ] **Step 2: Run the tests and confirm that they fail.**

Run: `scripts/test.sh -only-testing:NotchyTests/ModuleLifecycleTests`
Expected: FAIL with a compile error, because `ModuleLifecycle` has no member `setHasScreen`.

- [ ] **Step 3: Rename the state and the gate in `ModuleStatus` and `ModuleLifecycle`.** In `Notchy/Settings/ModuleStatus.swift`, replace `@Published var hasNotch = true` with:

```swift
    @Published var hasScreen = true
```

In `Notchy/App/AppCoordinator.swift`, replace the doc comment above `ModuleLifecycle` with:

```swift
/// Decides which modules run, driven by user settings, screen availability, and Accessibility
/// trust. Extracted from `AppCoordinator` so the policy (start/stop bookkeeping, accessibility
/// restart) can be unit tested without touching AppKit (menu bar, windows, real screen
/// detection) — it only needs a settings store and two injectable seams: the module factory
/// and an `isTrusted` provider.
```

Replace `setHasNotch` with:

```swift
    /// Nothing can be shown without the island, so no module may run without a screen for it.
    func setHasScreen(_ hasScreen: Bool) {
        status.hasScreen = hasScreen
        applySettings()
    }
```

In `applySettings()`, change the gate to:

```swift
            let shouldRun = settings.isEnabled(id) && status.hasScreen
```

- [ ] **Step 4: Rewire the coordinator and drop the "no notch" UI.** In `AppCoordinator.start()`, replace the `panelController.onNotchAvailabilityChange = { ... }` block and the comment above it with:

```swift
        // rebuild() (called synchronously by panelController.start() below) always reports the
        // first availability, so it also performs the very first applySettings().
        panelController.onScreenAvailabilityChange = { [weak self] hasScreen in
            self?.lifecycle.setHasScreen(hasScreen)
        }
```

Rename the callback in `Notchy/Notch/NotchPanelController.swift`:

```bash
sed -i '' 's/onNotchAvailabilityChange/onScreenAvailabilityChange/g' Notchy/Notch/NotchPanelController.swift
```

In `Notchy/App/MenuBarController.swift`, delete three things:
- the `noNotchItem` property (line 6)
- its three setup lines in `init` (`noNotchItem.isEnabled = false`, `noNotchItem.isHidden = true`, `menu.addItem(noNotchItem)`)
- the whole `setHasNotch(_:)` method, plus the blank line after it

In `Notchy/Settings/SettingsView.swift`, delete this block at the top of the `Form`:

```swift
            if !status.hasNotch {
                Text("Çentikli ekran bulunamadı. Notchy yalnızca yerleşik çentikli ekranda çalışır.")
                    .foregroundStyle(.orange)
            }
```

Check that no old names are left: `grep -rn "hasNotch\|HasNotch\|noNotchItem\|onNotchAvailabilityChange" Notchy NotchyTests` should print nothing.

- [ ] **Step 5: Run the full suite and confirm that it passes.**

Run: `scripts/test.sh`
Expected: exit status 0.

- [ ] **Step 6: Commit.**

```bash
git add Notchy/App/AppCoordinator.swift Notchy/Settings/ModuleStatus.swift Notchy/App/MenuBarController.swift \
  Notchy/Settings/SettingsView.swift Notchy/Notch/NotchPanelController.swift NotchyTests/AppCoordinatorTests.swift
git commit -m "refactor: run modules whenever a screen exists instead of a notch

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

### Task 3: Move the island to the screen under the mouse

**Files:**
- Modify: `Notchy/Notch/NotchPanelController.swift` (whole file)
- Modify: `Notchy/Notch/NotchView.swift`: struct `NotchView`, lines 3-24
- Modify: `docs/superpowers/specs/2026-09-23-notchy-design.md`: lines 13, 19 and 54
- Modify: `README.md`: lines 5-12

**Interfaces:**
- Consumes from Task 1: `NotchGeometry.placement(...)`, `NotchGeometry.screenIndex(containing:in:)`, `NotchLayout.isHidden(...)`
- Consumes from Task 2: `onScreenAvailabilityChange`
- Produces: `NotchView(viewModel:notchSize:isVirtualNotch:)`

- [ ] **Step 1: Hide the idle island on a virtual notch.** In `Notchy/Notch/NotchView.swift`, add these to `NotchView`, right after `let notchSize: CGSize`:

```swift
    /// True on screens without a physical notch, where the idle island is hidden.
    let isVirtualNotch: Bool
```

Add them again after the `islandSize` property:

```swift
    private var isHidden: Bool {
        NotchLayout.isHidden(state: viewModel.state, isMediaPlaying: isMediaPlaying, isVirtualNotch: isVirtualNotch)
    }
```

In `body`, add the opacity modifier right after `.clipShape(...)`. The existing spring animations on `state` and `isMediaPlaying` then also animate the fade.

```swift
            .opacity(isHidden ? 0 : 1)
```

- [ ] **Step 2: Make the panel follow the mouse.** Replace the whole contents of `Notchy/Notch/NotchPanelController.swift` with the code below. `notchedScreen()` goes away. First run `grep -rn notchedScreen Notchy NotchyTests`; it must show nothing outside this file.

```swift
import AppKit
import Combine
import SwiftUI

/// Owns the notch panel and keeps it on the screen under the mouse. Hover is tracked with
/// mouse-moved monitors so the panel can ignore mouse events (click-through) everywhere except
/// over the island itself.
@MainActor
final class NotchPanelController {
    /// Whether any screen can show the island: reported once at start, then only on change.
    var onScreenAvailabilityChange: ((Bool) -> Void)?

    private let viewModel: NotchViewModel
    private var panel: NotchPanel?
    private var notchSize: CGSize = .zero
    /// Frame of the screen the panel is on, used to notice the mouse moving to another screen.
    private var screenFrame: CGRect?
    private var hasScreen: Bool?
    private var monitors: [Any] = []
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        rebuild()
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)
        // A peek ending or the island collapsing can change the click-capture region (via
        // NotchLayout.islandSize) without any mouse movement, so a stale `ignoresMouseEvents`
        // must also be corrected on state/media changes, not only on `.mouseMoved`.
        // `updateHover()` is idempotent when hover state is unchanged, so this can't feedback loop.
        viewModel.$state.combineLatest(viewModel.$media)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in self?.updateHover() }
            .store(in: &cancellables)
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] _ in
            self?.updateHover()
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] event in
            self?.updateHover()
            return event
        }) {
            monitors.append(local)
        }
    }

    private static func screenUnderMouse() -> NSScreen? {
        let screens = NSScreen.screens
        return NotchGeometry.screenIndex(containing: NSEvent.mouseLocation, in: screens.map(\.frame))
            .map { screens[$0] }
    }

    private func rebuild() {
        guard let screen = Self.screenUnderMouse() ?? NSScreen.screens.first else {
            Log.notch.info("Ekran bulunamadı")
            panel?.orderOut(nil)
            panel = nil
            screenFrame = nil
            setHasScreen(false)
            return
        }
        show(on: screen)
        setHasScreen(true)
    }

    private func show(on screen: NSScreen) {
        let placement = NotchGeometry.placement(
            screenWidth: screen.frame.width,
            safeAreaTop: screen.safeAreaInsets.top,
            leftAuxiliaryWidth: screen.auxiliaryTopLeftArea?.width,
            rightAuxiliaryWidth: screen.auxiliaryTopRightArea?.width,
            menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY)
        notchSize = placement.size
        screenFrame = screen.frame
        let frame = NotchGeometry.panelFrame(screenFrame: screen.frame,
                                             panelSize: NotchLayout.panelSize(notch: placement.size))
        let panel = self.panel ?? NotchPanel(frame: frame)
        let host = NotchHostingView(rootView: NotchView(viewModel: viewModel, notchSize: placement.size,
                                                        isVirtualNotch: placement.isVirtual))
        host.sizingOptions = []
        host.onSwipe = { [weak self] direction in self?.viewModel.handleSwipe(direction) }
        panel.contentView = host
        panel.setFrame(frame, display: true)
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func setHasScreen(_ value: Bool) {
        guard value != hasScreen else { return }
        hasScreen = value
        onScreenAvailabilityChange?(value)
    }

    /// Moves the island to the screen under the mouse. An expanded island stays until it
    /// collapses; the mouse has left it, so that happens after the collapse delay.
    private func followMouse() {
        guard panel != nil, viewModel.state != .expanded,
              let screen = Self.screenUnderMouse(), screen.frame != screenFrame else { return }
        show(on: screen)
    }

    private func updateHover() {
        followMouse()
        guard let panel else { return }
        let island = NotchLayout.islandSize(for: viewModel.state,
                                            isMediaPlaying: viewModel.media?.isPlaying == true,
                                            notch: notchSize)
        let local = NotchLayout.islandRect(islandSize: island, panelSize: panel.frame.size)
        // Grow by 2 pt vertically so the very top pixel row (y == maxY) counts as inside.
        let onScreen = local.offsetBy(dx: panel.frame.minX, dy: panel.frame.minY).insetBy(dx: 0, dy: -2)
        let inside = onScreen.contains(NSEvent.mouseLocation)
        panel.ignoresMouseEvents = !inside
        viewModel.hoverChanged(inside)
    }
}
```

- [ ] **Step 3: Update the docs.** Change three lines in `docs/superpowers/specs/2026-09-23-notchy-design.md`.

Line 13. Before:

```
- Yalnızca **yerleşik çentikli ekranda** çalışır. Çentikli ekran yoksa ada gösterilmez.
```

After:

```
- Ada farenin bulunduğu ekranda görünür: çentikli ekranda gerçek çentiğin üstünde, diğer ekranlarda sanal çentikte (bkz. [2026-09-23-external-display-design.md](2026-09-23-external-display-design.md)).
```

Line 19: remove `harici monitör desteği, ` from the out-of-scope list.

Line 54. Before:

```
- Çentikli ekran yoksa panel oluşturulmaz; menü çubuğu menüsünde "Çentikli ekran bulunamadı" gösterilir.
```

After:

```
- Panel farenin bulunduğu ekrana taşınır; çentiksiz ekranlarda sanal çentik kullanılır (bkz. [2026-09-23-external-display-design.md](2026-09-23-external-display-design.md)).
```

In `README.md`, add this bullet under `## Özellikler (v1)`, after the media bullet:

```
- Harici ekranlar: ada farenin olduğu ekrana geçer; çentiksiz ekranda boştayken gizlenir
```

Then replace `- Çentikli ekranlı MacBook, macOS 14+` with:

```
- macOS 14+; en iyi çentikli MacBook'ta çalışır, harici ve çentiksiz ekranlarda sanal çentik kullanılır
```

- [ ] **Step 4: Run the full suite.**

Run: `scripts/test.sh`
Expected: exit status 0.

- [ ] **Step 5: Commit.**

```bash
git add Notchy/Notch/NotchPanelController.swift Notchy/Notch/NotchView.swift \
  docs/superpowers/specs/2026-09-23-notchy-design.md README.md
git commit -m "feat: move the island to the screen under the mouse

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

Afterwards the user checks it by hand (spec §7):
- move the mouse between the two screens
- on the external screen: the island is hidden when idle, and the equalizer shows while music plays
- a volume key on the external screen
- hovering over the top center opens the island
- move the mouse to the other screen while the island is open
- use the Mac with the lid closed
