@MainActor
protocol MediaSource: AnyObject {
    var onUpdate: ((MediaState?) -> Void)? { get set }
    /// Called once when the source gives up for good.
    var onFailure: (() -> Void)? { get set }
    func start()
    func stop()
    func send(_ command: MediaCommand)
}
