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

/// The timer row under the controls: the minutes field, or the running countdown.
struct CountdownRowView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var minutes = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if let countdown = viewModel.countdown {
                CountdownText(countdown: countdown)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                button(countdown.isPaused ? "play.fill" : "pause.fill") {
                    countdown.isPaused ? viewModel.resumeCountdown() : viewModel.pauseCountdown()
                }
                button("xmark") { viewModel.cancelCountdown() }
            } else {
                TextField("dk", text: $minutes)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(width: 56, height: 22)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    .focused($isFieldFocused)
                    .onSubmit { viewModel.startCountdown(minutes: Int(minutes) ?? 0) }
                    .onExitCommand { viewModel.cancelCountdownEntry() }
                    .onAppear {
                        minutes = ""
                        // The panel becomes key in the same update; focus once it is.
                        DispatchQueue.main.async { isFieldFocused = true }
                    }
            }
        }
        .frame(height: 28)
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
