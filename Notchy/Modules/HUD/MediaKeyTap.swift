import AppKit
import CoreGraphics

/// Intercepts volume/brightness keys. Requires Accessibility permission.
@MainActor
final class MediaKeyTap {
    /// Return true when the key was handled; the event is then swallowed.
    var handler: ((MediaKeyEvent, _ fine: Bool) -> Bool)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    /// Returns false when the tap cannot be created (no Accessibility permission).
    func start() -> Bool {
        let mask: CGEventMask = (1 << CGEventMask(MediaKeyParser.systemDefinedEventType))
            | (1 << CGEventMask(CGEventType.keyDown.rawValue))
            | (1 << CGEventMask(CGEventType.keyUp.rawValue))
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let keyTap = Unmanaged<MediaKeyTap>.fromOpaque(refcon).takeUnretainedValue()
                // The tap's run loop source is on the main run loop. A captured var avoids
                // assumeIsolated's Sendable requirement on its return type.
                var result: Unmanaged<CGEvent>? = Unmanaged.passUnretained(event)
                MainActor.assumeIsolated { result = keyTap.handle(type: type, event: event) }
                return result
            },
            userInfo: refcon) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let fine = event.flags.contains(.maskAlternate) && event.flags.contains(.maskShift)
        let parsed: MediaKeyEvent?
        if type.rawValue == MediaKeyParser.systemDefinedEventType {
            guard let nsEvent = NSEvent(cgEvent: event) else { return Unmanaged.passUnretained(event) }
            parsed = MediaKeyParser.parse(subtype: nsEvent.subtype.rawValue, data1: nsEvent.data1)
        } else {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            parsed = MediaKeyParser.brightnessKey(forKeyCode: keyCode).map {
                MediaKeyEvent(key: $0,
                              isDown: type == .keyDown,
                              isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
            }
        }
        guard let parsed, let handler, handler(parsed, fine) else { return Unmanaged.passUnretained(event) }
        return nil
    }
}
