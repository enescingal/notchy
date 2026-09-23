import Foundation

/// Reads private battery properties that IOBluetoothDevice exposes for Apple/Beats headphones.
enum BluetoothBatteryReader {
    static func read(from device: NSObject) -> BluetoothBattery? {
        func level(_ key: String) -> Int? {
            guard device.responds(to: NSSelectorFromString(key)),
                  let number = device.value(forKey: key) as? NSNumber,
                  number.intValue > 0 else { return nil }
            return number.intValue
        }
        let battery = BluetoothBattery(
            left: level("batteryPercentLeft"),
            right: level("batteryPercentRight"),
            caseLevel: level("batteryPercentCase"),
            single: level("batteryPercentSingle"))
        return battery.isEmpty ? nil : battery
    }
}
