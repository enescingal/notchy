import Foundation
import IOBluetooth

@MainActor
final class BluetoothModule: NSObject, NotchModule {
    private weak var viewModel: NotchViewModel?
    private let scheduler: Scheduler
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    /// Registering for connect notifications immediately reports devices that are already
    /// connected; those are not new connections and must not show a peek.
    private var alreadyConnected: Set<String> = []

    init(viewModel: NotchViewModel, scheduler: Scheduler) {
        self.viewModel = viewModel
        self.scheduler = scheduler
        super.init()
    }

    func start() {
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        alreadyConnected = Set(paired.filter { $0.isConnected() }.compactMap { $0.addressString })
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
    }

    func stop() {
        connectNotification?.unregister()
        connectNotification = nil
        disconnectNotifications.values.forEach { $0.unregister() }
        disconnectNotifications.removeAll()
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard let address = device.addressString else { return }
        if disconnectNotifications[address] == nil {
            disconnectNotifications[address] = device.register(
                forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
        }
        if alreadyConnected.remove(address) != nil { return }

        let name = device.nameOrAddress ?? "Kulaklık"
        let kind = DeviceKind.classify(name: name, majorClass: device.deviceClassMajor)
        guard kind.isAudio else { return }
        // Battery levels are published a moment after the link comes up.
        scheduler.schedule(after: 1.5) { [weak self, weak device] in
            guard let self, let device, device.isConnected() else { return }
            let event = BluetoothEvent(name: name, kind: kind, isConnected: true,
                                       battery: BluetoothBatteryReader.read(from: device))
            self.viewModel?.present(.bluetooth(event))
        }
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard let address = device.addressString else { return }
        disconnectNotifications.removeValue(forKey: address)?.unregister()
        let name = device.nameOrAddress ?? "Kulaklık"
        let kind = DeviceKind.classify(name: name, majorClass: device.deviceClassMajor)
        guard kind.isAudio else { return }
        viewModel?.present(.bluetooth(BluetoothEvent(name: name, kind: kind, isConnected: false, battery: nil)))
    }
}
