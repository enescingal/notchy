import SwiftUI

/// The control row that is always at the top of the expanded island: brightness and volume
/// (with their current levels) on the left, timer and lock on the right.
struct QuickControlsView: View {
    let available: Set<QuickControl>
    let levels: ControlLevels
    let isTimerActive: Bool
    let onControl: (QuickControl) -> Void
    let onTimer: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 28) {
                HStack(spacing: 2) {
                    button("sun.min.fill", .brightnessDown)
                    level(levels.brightness)
                    button("sun.max.fill", .brightnessUp)
                }
                HStack(spacing: 2) {
                    button("speaker.wave.1.fill", .volumeDown)
                    level(levels.volume)
                    button("speaker.wave.3.fill", .volumeUp)
                }
            }
            Spacer(minLength: 16)
            HStack(spacing: 2) {
                timerButton
                button("lock.fill", .lockScreen)
            }
        }
    }

    /// The current level between a pair of buttons, faded; a dash while unknown.
    private func level(_ value: Double?) -> some View {
        Text(value.map { "%\(Int(($0 * 100).rounded()))" } ?? "–")
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.5))
            .frame(width: 32)
    }

    private var timerButton: some View {
        Button(action: onTimer) {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isTimerActive ? Color.orange : Color.white)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
