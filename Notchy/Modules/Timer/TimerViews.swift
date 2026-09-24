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
                TimerRowButton(symbol: countdown.isPaused ? "play.fill" : "pause.fill") {
                    countdown.isPaused ? viewModel.resumeCountdown() : viewModel.pauseCountdown()
                }
                TimerRowButton(symbol: "xmark") { viewModel.cancelCountdown() }
            }
            .frame(height: 28)
        }
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

/// Elapsed time: live while running, frozen while paused.
struct StopwatchText: View {
    let stopwatch: StopwatchState

    var body: some View {
        switch stopwatch {
        // A past date makes the timer style count up.
        case .running(let startDate): Text(startDate, style: .timer)
        case .paused(let elapsed): Text(CountdownFormat.string(from: elapsed, rounding: .down))
        }
    }
}

/// The running or paused stopwatch, in its own row under the countdown.
struct StopwatchRowView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        if let stopwatch = viewModel.stopwatch {
            HStack(spacing: 8) {
                StopwatchText(stopwatch: stopwatch)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                TimerRowButton(symbol: stopwatch.isPaused ? "play.fill" : "pause.fill") {
                    stopwatch.isPaused ? viewModel.resumeStopwatch() : viewModel.pauseStopwatch()
                }
                TimerRowButton(symbol: "xmark") { viewModel.resetStopwatch() }
            }
            .frame(height: 28)
        }
    }
}

struct TimerRowButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
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
