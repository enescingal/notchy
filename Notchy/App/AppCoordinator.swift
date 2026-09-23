import AppKit

@MainActor
final class AppCoordinator {
    let viewModel = NotchViewModel(scheduler: MainScheduler())
    private lazy var panelController = NotchPanelController(viewModel: viewModel)

    func start() {
        panelController.start()
    }
}
