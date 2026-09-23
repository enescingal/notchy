import AppKit
import Combine
import SwiftUI

/// Owns the notch panel. Hover is tracked with mouse-moved monitors so the panel can ignore
/// mouse events (click-through) everywhere except over the island itself.
@MainActor
final class NotchPanelController {
    var onNotchAvailabilityChange: ((Bool) -> Void)?

    private let viewModel: NotchViewModel
    private var panel: NotchPanel?
    private var notchSize: CGSize = .zero
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

    static func notchedScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
    }

    private func rebuild() {
        guard let screen = Self.notchedScreen(),
              let size = NotchGeometry.notchSize(
                  screenWidth: screen.frame.width,
                  safeAreaTop: screen.safeAreaInsets.top,
                  leftAuxiliaryWidth: screen.auxiliaryTopLeftArea?.width,
                  rightAuxiliaryWidth: screen.auxiliaryTopRightArea?.width) else {
            Log.notch.info("Çentikli ekran bulunamadı")
            panel?.orderOut(nil)
            panel = nil
            onNotchAvailabilityChange?(false)
            return
        }
        notchSize = size
        let frame = NotchGeometry.panelFrame(screenFrame: screen.frame, panelSize: NotchLayout.panelSize(notch: size))
        let panel = self.panel ?? NotchPanel(frame: frame)
        let host = NotchHostingView(rootView: NotchView(viewModel: viewModel, notchSize: size))
        host.sizingOptions = []
        host.onSwipe = { [weak self] direction in self?.viewModel.handleSwipe(direction) }
        panel.contentView = host
        panel.setFrame(frame, display: true)
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        self.panel = panel
        onNotchAvailabilityChange?(true)
    }

    private func updateHover() {
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
