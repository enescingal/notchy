import SwiftUI

struct OnboardingView: View {
    @ObservedObject var status: ModuleStatus
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "capsule.fill").font(.system(size: 44))
            Text("Notchy'ye hoş geldin").font(.title2.bold())
            Text("Notchy çentiğini canlı bir alana dönüştürür: müzik kontrolleri, ses ve parlaklık göstergesi, şarj ve AirPods bildirimleri.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            GroupBox {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hand.raised.fill").foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Erişilebilirlik izni").font(.headline)
                        Text("Ses ve parlaklık tuşlarını yakalamak için gerekir. İzin vermezsen Notchy yine çalışır; sadece sistemin kendi göstergesi görünmeye devam eder.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        if status.accessibilityGranted {
                            Label("İzin verildi", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Button("İzin ver") { Accessibility.requestPrompt() }
                        }
                    }
                }
                .padding(4)
            }
            Button("Başla", action: onFinish)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
        .padding(28)
        .frame(width: 420)
    }
}
