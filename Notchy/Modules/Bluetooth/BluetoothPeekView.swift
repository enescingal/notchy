import SwiftUI

struct BluetoothPeekView: View {
    let event: BluetoothEvent
    let notchWidth: CGFloat

    var body: some View {
        PeekLayout(notchWidth: notchWidth) {
            HStack(spacing: 6) {
                Image(systemName: Self.symbolName(for: event.kind))
                    .font(.system(size: 14, weight: .semibold))
                Text(event.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundStyle(.white)
        } right: {
            if !event.isConnected {
                status("Bağlantı kesildi")
            } else if let text = Self.batteryText(event.battery) {
                Text(text)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.green)
                    .lineLimit(1)
            } else {
                status("Bağlandı")
            }
        }
    }

    private func status(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.7))
            .lineLimit(1)
    }

    static func symbolName(for kind: DeviceKind) -> String {
        switch kind {
        case .airpods: return "airpods"
        case .airpodsPro: return "airpodspro"
        case .airpodsMax: return "airpodsmax"
        case .headphones, .other: return "headphones"
        }
    }

    /// "S" = sol (left), "D" = sağ (right).
    static func batteryText(_ battery: BluetoothBattery?) -> String? {
        guard let battery, !battery.isEmpty else { return nil }
        if let left = battery.left, let right = battery.right {
            return left == right ? "%\(left)" : "S %\(left) · D %\(right)"
        }
        if let level = battery.single ?? battery.left ?? battery.right { return "%\(level)" }
        if let level = battery.caseLevel { return "Kutu %\(level)" }
        return nil
    }
}
