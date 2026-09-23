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
                                            hasMedia: viewModel.media != nil,
                                            notch: notchSize)
        let local = NotchLayout.islandRect(islandSize: island, panelSize: panel.frame.size)
        // Grow by 2 pt vertically so the very top pixel row (y == maxY) counts as inside.
        let onScreen = local.offsetBy(dx: panel.frame.minX, dy: panel.frame.minY).insetBy(dx: 0, dy: -2)
        let inside = onScreen.contains(NSEvent.mouseLocation)
        panel.ignoresMouseEvents = !inside
        viewModel.hoverChanged(inside)
    }
}
