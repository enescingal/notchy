import Foundation
import IOKit.ps

@MainActor
final class BatteryModule: NotchModule {
    private weak var viewModel: NotchViewModel?
    private var detector = BatteryEventDetector()
    private var runLoopSource: CFRunLoopSource?

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        guard Self.readInternalBattery() != nil else {
            Log.battery.info("Dahili pil yok, pil modülü kapalı")
            return
        }
        detector = BatteryEventDetector()
        handleChange() // baseline
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let module = Unmanaged<BatteryModule>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { module.handleChange() }
        }, context)?.takeRetainedValue() else {
            Log.battery.error("Güç kaynağı bildirimi oluşturulamadı")
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
    }

    private func handleChange() {
        guard let reading = Self.readInternalBattery() else { return }
        if let event = detector.process(reading) {
            viewModel?.present(.battery(event))
        }
    }

    static func readInternalBattery() -> BatteryReading? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let max = description[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            return BatteryReading(
                percentage: Int((Double(current) / Double(max) * 100).rounded()),
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                isPluggedIn: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue)
        }
        return nil
    }
}
