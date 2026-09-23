/// A feature that listens to the system and feeds the notch. Modules never know about each other.
@MainActor
protocol NotchModule: AnyObject {
    func start()
    func stop()
}
