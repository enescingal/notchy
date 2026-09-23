import Foundation

/// Runs the bundled mediaremote-adapter through /usr/bin/perl and streams now-playing updates.
@MainActor
final class MediaRemoteAdapterSource: MediaSource {
    var onUpdate: ((MediaState?) -> Void)?
    var onFailure: (() -> Void)?

    private static let perl = URL(fileURLWithPath: "/usr/bin/perl")

    private let scriptURL: URL
    private let frameworkURL: URL
    private let scheduler: Scheduler
    private var process: Process?
    private var lineBuffer = LineBuffer()
    private var restartPolicy = RestartPolicy()
    private var isStopped = true

    init?(bundle: Bundle = .main, scheduler: Scheduler) {
        guard let directory = bundle.resourceURL?.appendingPathComponent("MediaRemoteAdapter") else { return nil }
        let script = directory.appendingPathComponent("mediaremote-adapter.pl")
        let framework = directory.appendingPathComponent("MediaRemoteAdapter.framework")
        guard FileManager.default.fileExists(atPath: script.path),
              FileManager.default.fileExists(atPath: framework.path) else { return nil }
        self.scriptURL = script
        self.frameworkURL = framework
        self.scheduler = scheduler
    }

    func start() {
        isStopped = false
        restartPolicy.reset()
        launch()
    }

    func stop() {
        isStopped = true
        guard let process else { return }
        process.terminationHandler = nil
        (process.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        if process.isRunning { process.terminate() }
        self.process = nil
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

    private func launch() {
        let process = Process()
        process.executableURL = Self.perl
        process.arguments = [scriptURL.path, frameworkURL.path, "stream", "--no-diff", "--no-artwork", "--debounce=100"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        lineBuffer = LineBuffer()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil // EOF; otherwise this keeps firing
                return
            }
            DispatchQueue.main.async { self?.receive(data) }
        }
        process.terminationHandler = { [weak self] finished in
            let status = finished.terminationStatus
            DispatchQueue.main.async { self?.processExited(status: status) }
        }
        do {
            try process.run()
            self.process = process
        } catch {
            Log.media.error("Medya adaptörü başlatılamadı: \(error.localizedDescription)")
            processExited(status: -1)
        }
    }

    private func receive(_ data: Data) {
        guard !isStopped else { return }
        for line in lineBuffer.append(data) {
            switch MediaPayloadParser.parse(line) {
            case .update(let media):
                restartPolicy.reset()
                onUpdate?(media)
            case .ignored:
                Log.media.debug("Ayrıştırılamayan adaptör satırı atlandı")
            }
        }
    }

    private func processExited(status: Int32) {
        process = nil
        guard !isStopped else { return }
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
