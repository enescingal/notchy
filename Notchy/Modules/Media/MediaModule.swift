@MainActor
final class MediaModule: NotchModule {
    private weak var viewModel: NotchViewModel?
    private let status: ModuleStatus
    private let makeSource: () -> MediaSource?
    private var source: MediaSource?

    init(viewModel: NotchViewModel, status: ModuleStatus, makeSource: @escaping () -> MediaSource?) {
        self.viewModel = viewModel
        self.status = status
        self.makeSource = makeSource
    }

    func start() {
        guard let source = makeSource() else {
            Log.media.error("Medya adaptörü uygulama paketinde bulunamadı")
            status.mediaUnavailable = true
            return
        }
        status.mediaUnavailable = false
        source.onUpdate = { [weak self] media in self?.viewModel?.updateMedia(media) }
        source.onFailure = { [weak self] in
            self?.status.mediaUnavailable = true
            self?.viewModel?.updateMedia(nil)
            self?.viewModel?.mediaCommandHandler = nil
        }
        viewModel?.mediaCommandHandler = { [weak source] command in source?.send(command) }
        source.start()
        self.source = source
    }

    func stop() {
        source?.stop()
        source = nil
        viewModel?.mediaCommandHandler = nil
        viewModel?.updateMedia(nil)
    }
}
