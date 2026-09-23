import AudioToolbox
import CoreAudio

/// Reads/writes the default output device volume and reports every change (ours or external).
@MainActor
final class VolumeController {
    var onChange: ((HUDState) -> Void)?

    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?

    private static let volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    private static let muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    private static let defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)

    var current: HUDState {
        HUDState(kind: .volume, level: Double(volume ?? 0), isMuted: isMuted)
    }

    var canSetVolume: Bool {
        var address = Self.volumeAddress
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr && settable.boolValue
    }

    func start() {
        deviceID = Self.defaultOutputDevice()
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.defaultDeviceChanged() }
        }
        var address = Self.defaultDeviceAddress
        let status = AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        if status != noErr { Log.hud.error("Varsayılan cihaz dinleyicisi eklenemedi: \(status)") }
        defaultDeviceListener = listener
        addDeviceListeners()
    }

    func stop() {
        removeDeviceListeners()
        if let defaultDeviceListener {
            var address = Self.defaultDeviceAddress
            let status = AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, defaultDeviceListener)
            if status != noErr { Log.hud.error("Varsayılan cihaz dinleyicisi kaldırılamadı: \(status)") }
        }
        defaultDeviceListener = nil
    }

    func step(up: Bool, fine: Bool) {
        if isMuted { setMuted(false) }
        setVolume(Float(HUDStep.next(from: Double(volume ?? 0), up: up, fine: fine)))
    }

    func toggleMute() {
        setMuted(!isMuted)
    }

    private func defaultDeviceChanged() {
        removeDeviceListeners()
        deviceID = Self.defaultOutputDevice()
        addDeviceListeners()
    }

    private func addDeviceListeners() {
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.onChange?(self.current)
            }
        }
        var volume = Self.volumeAddress
        var mute = Self.muteAddress
        let volumeStatus = AudioObjectAddPropertyListenerBlock(deviceID, &volume, .main, listener)
        if volumeStatus != noErr { Log.hud.error("Ses dinleyicisi eklenemedi: \(volumeStatus)") }
        let muteStatus = AudioObjectAddPropertyListenerBlock(deviceID, &mute, .main, listener)
        if muteStatus != noErr { Log.hud.error("Sessiz dinleyicisi eklenemedi: \(muteStatus)") }
        deviceListener = listener
    }

    private func removeDeviceListeners() {
        guard let deviceListener else { return }
        var volume = Self.volumeAddress
        var mute = Self.muteAddress
        let volumeStatus = AudioObjectRemovePropertyListenerBlock(deviceID, &volume, .main, deviceListener)
        if volumeStatus != noErr { Log.hud.error("Ses dinleyicisi kaldırılamadı: \(volumeStatus)") }
        let muteStatus = AudioObjectRemovePropertyListenerBlock(deviceID, &mute, .main, deviceListener)
        if muteStatus != noErr { Log.hud.error("Sessiz dinleyicisi kaldırılamadı: \(muteStatus)") }
        self.deviceListener = nil
    }

    private var volume: Float? {
        var address = Self.volumeAddress
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private var isMuted: Bool {
        var address = Self.muteAddress
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr else { return false }
        return value != 0
    }

    private func setVolume(_ newValue: Float) {
        var address = Self.volumeAddress
        var value = Float32(newValue)
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        if status != noErr { Log.hud.error("Ses ayarlanamadı: \(status)") }
    }

    private func setMuted(_ muted: Bool) {
        var address = Self.muteAddress
        var value: UInt32 = muted ? 1 : 0
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        if status != noErr { Log.hud.error("Sessize alınamadı: \(status)") }
    }

    private static func defaultOutputDevice() -> AudioObjectID {
        var address = defaultDeviceAddress
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        if status != noErr {
            Log.hud.error("Varsayılan çıkış cihazı alınamadı: \(status)")
        } else if device == kAudioObjectUnknown {
            Log.hud.error("Varsayılan çıkış cihazı bulunamadı")
        }
        return device
    }
}
