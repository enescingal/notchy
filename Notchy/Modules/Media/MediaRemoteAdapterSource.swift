import Foundation

/// Runs the bundled mediaremote-adapter through /usr/bin/perl and streams now-playing updates.
@MainActor
final class MediaRemoteAdapterSource: MediaSource {
    var onUpdate: ((MediaState?) -> Void)?
    var onFailure: (() -> Void)?

    private static let perl = URL(fileURLWithPath: "/usr/bin/perl")
    /// Once a stream process has stayed up this long without exiting, treat it as healthy
    /// again and reset the restart backoff.
    private static let stableRunDuration: TimeInterval = 10

    private let scriptURL: URL
    private let frameworkURL: URL
    private let scheduler: Scheduler
    private let launchProcess: @MainActor (URL, [String]) throws -> StreamProcess

    private var process: StreamProcess?
    private var lineBuffer = LineBuffer()
    private var restartPolicy = RestartPolicy()
    private var isStopped = true

    init?(
        bundle: Bundle = .main,
        scheduler: Scheduler,
        launchProcess: @escaping @MainActor (URL, [String]) throws -> StreamProcess = MediaRemoteAdapterSource.launchRealProcess
    ) {
        guard let directory = bundle.resourceURL?.appendingPathComponent("MediaRemoteAdapter") else { return nil }
        let script = directory.appendingPathComponent("mediaremote-adapter.pl")
        let framework = directory.appendingPathComponent("MediaRemoteAdapter.framework")
        guard FileManager.default.fileExists(atPath: script.path),
              FileManager.default.fileExists(atPath: framework.path) else { return nil }
        self.scriptURL = script
        self.frameworkURL = framework
        self.scheduler = scheduler
        self.launchProcess = launchProcess
    }

    func start() {
        isStopped = false
        restartPolicy.reset()
        launch()
    }

    func stop() {
        isStopped = true
        process?.stop()
        process = nil
    }

    func send(_ command: MediaCommand) {
        let process = Process()
        process.executableURL = Self.perl
        process.arguments = [scriptURL.path, frameworkURL.path, "send", String(command.rawValue)]
        do {
            try process.run()
        } catch {
            Log.media.error("Medya komutu gönderilemedi: \(error.localizedDescription)")
        }
    }

    private static func launchRealProcess(executableURL: URL, arguments: [String]) throws -> StreamProcess {
        let process = RealStreamProcess(executableURL: executableURL, arguments: arguments)
        try process.start()
        return process
    }

    private func launch() {
        lineBuffer = LineBuffer()
        let arguments = [scriptURL.path, frameworkURL.path, "stream", "--no-diff", "--no-artwork", "--debounce=100"]
        let newProcess: StreamProcess
        do {
            newProcess = try launchProcess(Self.perl, arguments)
        } catch {
            Log.media.error("Medya adaptörü başlatılamadı: \(error.localizedDescription)")
            handleExit(status: -1, processID: nil)
            return
        }
        process = newProcess
        let processID = ObjectIdentifier(newProcess)
        newProcess.onOutput = { [weak self] data in
            guard let self, self.isCurrent(processID) else { return } // stale output from a replaced process
            self.receive(data)
        }
        newProcess.onExit = { [weak self] status in
            self?.handleExit(status: status, processID: processID)
        }
        scheduler.schedule(after: Self.stableRunDuration) { [weak self] in
            guard let self, self.isCurrent(processID) else { return }
            self.restartPolicy.reset()
        }
    }

    private func isCurrent(_ id: ObjectIdentifier) -> Bool {
        guard let process else { return false }
        return ObjectIdentifier(process) == id
    }

    private func receive(_ data: Data) {
        guard !isStopped else { return }
        for line in lineBuffer.append(data) {
            switch MediaPayloadParser.parse(line) {
            case .update(let media):
                onUpdate?(media)
            case .ignored:
                Log.media.debug("Ayrıştırılamayan adaptör satırı atlandı")
            }
        }
    }

    private func handleExit(status: Int32, processID: ObjectIdentifier?) {
        guard !isStopped else { return }
        // A nil processID means launching itself failed, before any process was current.
        // Otherwise ignore a stale exit notification from a process we've already replaced.
        if let processID, !isCurrent(processID) { return }
        process = nil
        onUpdate?(nil)
        guard let delay = restartPolicy.nextDelay() else {
            Log.media.error("Medya adaptörü sürekli kapanıyor; medya modülü devre dışı")
            isStopped = true
            onFailure?()
            return
        }
        Log.media.error("Medya adaptörü kapandı (kod \(status)); \(delay) sn sonra yeniden başlatılıyor")
        scheduler.schedule(after: delay) { [weak self] in
            guard let self, !self.isStopped else { return }
            self.launch()
        }
    }
}
