import Foundation

/// A running `mediaremote-adapter stream` subprocess. Abstracted so
/// `MediaRemoteAdapterSource` can be driven by a fake in tests.
@MainActor
protocol StreamProcess: AnyObject {
    var onOutput: ((Data) -> Void)? { get set }
    var onExit: ((Int32) -> Void)? { get set }
    func stop()
}

/// Wraps a real `Process` running the adapter's `stream` subcommand.
@MainActor
final class RealStreamProcess: StreamProcess {
    var onOutput: ((Data) -> Void)?
    var onExit: ((Int32) -> Void)?

    private let process = Process()
    private let pipe = Pipe()

    init(executableURL: URL, arguments: [String]) {
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil // EOF; otherwise this keeps firing
                return
            }
            DispatchQueue.main.async { self?.onOutput?(data) }
        }
        process.terminationHandler = { [weak self] finished in
            let status = finished.terminationStatus
            DispatchQueue.main.async { self?.onExit?(status) }
        }
    }

    /// Starts the underlying process. Throws if it cannot be launched.
    func start() throws {
        try process.run()
    }

    func stop() {
        process.terminationHandler = nil
        pipe.fileHandleForReading.readabilityHandler = nil
        if process.isRunning { process.terminate() }
    }
}
