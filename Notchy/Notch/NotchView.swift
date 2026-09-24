import SwiftUI

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    let notchSize: CGSize
    /// True on screens without a physical notch, where the idle island is hidden.
    let isVirtualNotch: Bool

    private var islandContent: IslandContent { viewModel.islandContent }

    private var islandSize: CGSize {
        NotchLayout.islandSize(for: viewModel.state, content: islandContent, notch: notchSize)
    }

    private var isHidden: Bool {
        NotchLayout.isHidden(state: viewModel.state, content: islandContent, isVirtualNotch: isVirtualNotch)
    }

    private var bottomRadius: CGFloat { viewModel.state == .expanded ? 22 : 10 }

    var body: some View {
        content
            .frame(width: islandSize.width, height: islandSize.height)
            .background(Color.black)
            .clipShape(NotchShape(topRadius: NotchLayout.earRadius, bottomRadius: bottomRadius))
            .opacity(isHidden ? 0 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: viewModel.state)
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: islandContent)
            .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .closed:
            ClosedContentView(isMediaPlaying: islandContent.isMediaPlaying, countdown: viewModel.countdown,
                              stopwatch: viewModel.stopwatch)
        case .peek(let peek):
            PeekContentView(content: peek, notchWidth: notchSize.width)
        case .expanded:
            ExpandedContentView(viewModel: viewModel, notchSize: notchSize)
        }
    }
}

struct ClosedContentView: View {
    let isMediaPlaying: Bool
    let countdown: CountdownState?
    let stopwatch: StopwatchState?

    var body: some View {
        HStack {
            // Like the iPhone timer: the icon left of the notch, the time right of it. A timer
            // takes the right side, so the equalizer waits until it ends; with both running the
            // countdown wins, since it has a deadline.
            if let countdown {
                Image(systemName: "timer")
                    .padding(.leading, NotchLayout.earRadius + 6)
                Spacer()
                CountdownText(countdown: countdown)
                    .padding(.trailing, NotchLayout.earRadius + 6)
            } else if let stopwatch {
                Image(systemName: "stopwatch")
                    .padding(.leading, NotchLayout.earRadius + 6)
                Spacer()
                StopwatchText(stopwatch: stopwatch)
                    .padding(.trailing, NotchLayout.earRadius + 6)
            } else {
                Spacer()
                if isMediaPlaying {
                    EqualizerView().padding(.trailing, NotchLayout.earRadius + 10)
                }
            }
        }
        .font(.system(size: 12, weight: .semibold).monospacedDigit())
        .foregroundStyle(.orange)
        .frame(maxHeight: .infinity)
    }
}

struct PeekContentView: View {
    let content: PeekContent
    let notchWidth: CGFloat

    var body: some View {
        switch content {
        case .hud(let hud): HUDPeekView(hud: hud, notchWidth: notchWidth)
        case .battery(let event): BatteryPeekView(event: event, notchWidth: notchWidth)
        case .bluetooth(let event): BluetoothPeekView(event: event, notchWidth: notchWidth)
        case .timerDone: TimerDonePeekView(notchWidth: notchWidth)
        }
    }
}

struct ExpandedContentView: View {
    @ObservedObject var viewModel: NotchViewModel
    let notchSize: CGSize

    var body: some View {
        VStack(spacing: 0) {
            // The strip beside the notch shows the date and time, or the same HUD as a
            // closed-state peek while one is up.
            Group {
                if let hud = viewModel.expandedHUD {
                    HUDPeekView(hud: hud, notchWidth: notchSize.width,
                                sideWidth: NotchLayout.expandedSideSpace(notch: notchSize))
                } else {
                    DateTimeStripView(notchWidth: notchSize.width,
                                      sideWidth: NotchLayout.expandedSideSpace(notch: notchSize))
                }
            }
            .frame(height: notchSize.height)
            VStack(spacing: 8) {
                QuickControlsView(available: viewModel.availableControls,
                                  isTimerActive: viewModel.countdown != nil,
                                  isEditingCountdown: viewModel.isEditingCountdown,
                                  isStopwatchActive: viewModel.stopwatch != nil,
                                  onControl: { viewModel.perform($0) },
                                  onTimer: { viewModel.toggleCountdownEntry() },
                                  onStartCountdown: { viewModel.startCountdown(minutes: $0) },
                                  onCancelCountdownEntry: { viewModel.cancelCountdownEntry() },
                                  onStopwatch: { viewModel.startStopwatch() })
                if viewModel.countdown != nil {
                    CountdownRowView(viewModel: viewModel)
                }
                if viewModel.stopwatch != nil {
                    StopwatchRowView(viewModel: viewModel)
                }
                if let media = viewModel.media {
                    MediaExpandedView(media: media) { viewModel.send($0) }
                }
            }
            .padding(.horizontal, NotchLayout.contentInset)
            .frame(maxHeight: .infinity)
        }
    }
}
