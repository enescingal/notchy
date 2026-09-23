import SwiftUI

/// The control row that is always at the top of the expanded island.
struct QuickControlsView: View {
    let available: Set<QuickControl>
    let onControl: (QuickControl) -> Void

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 2) {
                button("sun.min.fill", .brightnessDown)
                button("sun.max.fill", .brightnessUp)
            }
            HStack(spacing: 2) {
                button("speaker.wave.1.fill", .volumeDown)
                button("speaker.wave.3.fill", .volumeUp)
            }
            button("lock.fill", .lockScreen)
        }
    }

    private func button(_ symbol: String, _ control: QuickControl) -> some View {
        let isAvailable = available.contains(control)
        return Button { onControl(control) } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.3)
    }
}
