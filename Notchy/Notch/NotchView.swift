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
            ClosedContentView(isMediaPlaying: islandContent.isMediaPlaying, countdown: viewModel.countdown)
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

    var body: some View {
        HStack {
            if let countdown {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    CountdownText(countdown: countdown)
                }
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.orange)
                .padding(.leading, NotchLayout.earRadius + 6)
            }
            Spacer()
            if isMediaPlaying {
                EqualizerView().padding(.trailing, NotchLayout.earRadius + 10)
            }
        }
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
            // The strip beside the notch shows the same HUD as a closed-state peek.
            Group {
                if let hud = viewModel.expandedHUD {
                    HUDPeekView(hud: hud, notchWidth: notchSize.width,
                                sideWidth: NotchLayout.expandedSideSpace(notch: notchSize))
                } else {
                    Color.clear
                }
            }
            .frame(height: notchSize.height)
            VStack(spacing: 8) {
                QuickControlsView(available: viewModel.availableControls,
                                  isTimerActive: viewModel.countdown != nil,
                                  onControl: { viewModel.perform($0) },
                                  onTimer: { viewModel.toggleCountdownEntry() })
                if viewModel.countdown != nil || viewModel.isEditingCountdown {
                    CountdownRowView(viewModel: viewModel)
                }
                if let media = viewModel.media {
                    MediaExpandedView(media: media) { viewModel.send($0) }
                }
            }
            .padding(.horizontal, NotchLayout.earRadius + 20)
            .frame(maxHeight: .infinity)
        }
    }
}
