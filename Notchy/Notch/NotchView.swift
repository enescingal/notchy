import SwiftUI

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    let notchSize: CGSize

    private var isMediaPlaying: Bool { viewModel.media?.isPlaying == true }

    private var islandSize: CGSize {
        NotchLayout.islandSize(for: viewModel.state, isMediaPlaying: isMediaPlaying, notch: notchSize)
    }

    private var bottomRadius: CGFloat { viewModel.state == .expanded ? 22 : 10 }

    var body: some View {
        content
            .frame(width: islandSize.width, height: islandSize.height)
            .background(Color.black)
            .clipShape(NotchShape(topRadius: NotchLayout.earRadius, bottomRadius: bottomRadius))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: viewModel.state)
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: isMediaPlaying)
            .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .closed:
            ClosedContentView(isMediaPlaying: isMediaPlaying)
        case .peek(let peek):
            PeekContentView(content: peek, notchWidth: notchSize.width)
        case .expanded:
            ExpandedContentView(viewModel: viewModel, notchHeight: notchSize.height)
        }
    }
}

struct ClosedContentView: View {
    let isMediaPlaying: Bool

    var body: some View {
        HStack {
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
        }
    }
}

struct ExpandedContentView: View {
    @ObservedObject var viewModel: NotchViewModel
    let notchHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            Group {
                if let media = viewModel.media {
                    MediaExpandedView(media: media) { viewModel.send($0) }
                } else {
                    Text("Şu an çalan bir şey yok")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, NotchLayout.earRadius + 20)
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            if let hud = viewModel.expandedHUD {
                HUDInlineView(hud: hud).padding(.bottom, 6)
            }
        }
    }
}
