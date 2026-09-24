import SwiftUI

/// The control row that is always at the top of the expanded island: brightness and volume
/// on the left, timer, stopwatch and lock on the right.
struct QuickControlsView: View {
    let available: Set<QuickControl>
    let isTimerActive: Bool
    let isEditingCountdown: Bool
    let isStopwatchActive: Bool
    let onControl: (QuickControl) -> Void
    let onTimer: () -> Void
    let onStartCountdown: (Int) -> Void
    let onCancelCountdownEntry: () -> Void
    let onStopwatch: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 28) {
                HStack(spacing: 2) {
                    button("sun.min.fill", .brightnessDown)
                    button("sun.max.fill", .brightnessUp)
                }
                HStack(spacing: 2) {
                    button("speaker.wave.1.fill", .volumeDown)
                    button("speaker.wave.3.fill", .volumeUp)
                }
            }
            Spacer(minLength: 16)
            HStack(spacing: 2) {
                toggleButton("timer", isActive: isTimerActive, action: onTimer)
                if isEditingCountdown {
                    CountdownField(onSubmit: onStartCountdown, onCancel: onCancelCountdownEntry)
                }
                toggleButton("stopwatch", isActive: isStopwatchActive, action: onStopwatch)
                button("lock.fill", .lockScreen)
            }
        }
    }

    /// Orange while its timer exists.
    private func toggleButton(_ symbol: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? Color.orange : Color.white)
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
