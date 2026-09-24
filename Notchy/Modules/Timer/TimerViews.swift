import SwiftUI

/// Remaining time: a live countdown while running, frozen while paused.
struct CountdownText: View {
    let countdown: CountdownState

    var body: some View {
        switch countdown {
        case .running(let endDate): Text(endDate, style: .timer)
        case .paused(let remaining): Text(CountdownFormat.string(from: remaining))
        }
    }
}

/// The minutes field that opens right beside the timer button; Enter starts, Esc closes.
struct CountdownField: View {
    let onSubmit: (Int) -> Void
    let onCancel: () -> Void
    @State private var minutes = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("dk", text: $minutes)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(width: 56, height: 22)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            .focused($isFocused)
            .onSubmit { onSubmit(Int(minutes) ?? 0) }
            .onExitCommand(perform: onCancel)
            .onAppear {
                // The panel becomes key in the same update; focus once it is.
                DispatchQueue.main.async { isFocused = true }
            }
    }
}

/// The running or paused countdown, in its own row under the controls.
struct CountdownRowView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        if let countdown = viewModel.countdown {
            HStack(spacing: 8) {
                CountdownText(countdown: countdown)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                button(countdown.isPaused ? "play.fill" : "pause.fill") {
                    countdown.isPaused ? viewModel.resumeCountdown() : viewModel.pauseCountdown()
                }
                button("xmark") { viewModel.cancelCountdown() }
            }
            .frame(height: 28)
        }
    }

    private func button(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct TimerDonePeekView: View {
    let notchWidth: CGFloat

    var body: some View {
        PeekLayout(notchWidth: notchWidth) {
            Text("Süre doldu")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        } right: {
            Image(systemName: "bell.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange)
        }
    }
}
