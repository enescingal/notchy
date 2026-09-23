import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var status: ModuleStatus
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("Modüller") {
                Toggle("Medya", isOn: $settings.mediaEnabled)
                if status.mediaUnavailable {
                    Text("Medya bilgisi alınamıyor").font(.caption).foregroundStyle(.red)
                }
                Toggle("Ses ve parlaklık göstergesi", isOn: $settings.hudEnabled)
                Toggle("Pil ve şarj", isOn: $settings.batteryEnabled)
                Toggle("AirPods ve Bluetooth", isOn: $settings.bluetoothEnabled)
            }
            Section("Davranış") {
                Toggle("Girişte başlat", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLogin.set(newValue)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                LabeledContent("Genişleme gecikmesi") {
                    HStack {
                        Slider(value: $settings.hoverDelay, in: 0...1, step: 0.05)
                        Text(String(format: "%.2f sn", settings.hoverDelay)).monospacedDigit().frame(width: 60)
                    }
                }
                LabeledContent("Bildirim süresi") {
                    HStack {
                        Slider(value: $settings.peekDuration, in: 1...6, step: 0.5)
                        Text(String(format: "%.1f sn", settings.peekDuration)).monospacedDigit().frame(width: 60)
                    }
                }
            }
            Section("İzinler") {
                HStack {
                    Text("Erişilebilirlik")
                    Spacer()
                    if status.accessibilityGranted {
                        Label("Verildi", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("İzin ver") {
                            Accessibility.openSystemSettings()
                        }
                    }
                }
                Text("Ses ve parlaklık tuşlarını yakalayıp sistem göstergesi yerine Notchy'nin göstergesini göstermek için gerekir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
