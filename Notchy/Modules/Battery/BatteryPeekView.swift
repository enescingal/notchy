import SwiftUI

struct BatteryPeekView: View {
    let event: BatteryEvent
    let notchWidth: CGFloat

    var body: some View {
        PeekLayout(notchWidth: notchWidth) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        } right: {
            HStack(spacing: 6) {
                Text("%\(event.percentage)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                Image(systemName: Self.symbolName(for: event))
                    .font(.system(size: 16))
            }
            .foregroundStyle(tint)
        }
    }

    private var title: String {
        switch event.kind {
        case .pluggedIn: return "Şarj oluyor"
        case .unplugged: return "Pil"
        case .low: return "Düşük pil"
        }
    }

    private var tint: Color {
        if event.kind == .pluggedIn || event.isCharging { return .green }
        return event.percentage <= 20 ? .red : .white
    }

    static func symbolName(for event: BatteryEvent) -> String {
        if event.kind == .pluggedIn || event.isCharging { return "battery.100percent.bolt" }
        switch event.percentage {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}
