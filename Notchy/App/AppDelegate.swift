import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private var coordinator: AppCoordinator?
    private var sigtermSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningTests else { return }
        let coordinator = AppCoordinator(settings: SettingsStore(defaults: .standard))
        coordinator.start()
        self.coordinator = coordinator
        installSigtermHandler()
        Log.app.info("Notchy başladı")
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stopAll()
    }

    /// `pkill`/`kill` deliver SIGTERM directly and bypass AppKit's normal quit flow (Cmd-Q,
    /// Dock quit, an Apple Event), which is what triggers `applicationWillTerminate`. Without
    /// this, a SIGTERM skips module teardown and leaves child processes (e.g. the media
    /// adapter) orphaned. Routing SIGTERM through a proper `NSApp.terminate` keeps teardown
    /// consistent no matter how the app is asked to quit.
    private func installSigtermHandler() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { NSApp.terminate(nil) }
        source.resume()
        sigtermSource = source
    }
}
