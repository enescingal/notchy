import SwiftUI

/// Three bouncing bars shown next to the notch while something is playing.
struct EqualizerView: View {
    @State private var phase = false
    private let heights: [CGFloat] = [0.5, 1.0, 0.7]

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(heights.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.white)
                    .frame(width: 3, height: 12 * (phase ? heights[index] : heights[(index + 1) % heights.count]))
            }
        }
        .frame(height: 12)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { phase.toggle() }
        }
    }
}

/// One row under the controls: the title on the left, playback controls on the right.
struct MediaExpandedView: View {
    let media: MediaState
    let onCommand: (MediaCommand) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(media.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 2) {
                button("backward.fill", .previous)
                button(media.isPlaying ? "pause.fill" : "play.fill", .togglePlayPause, size: 15)
                button("forward.fill", .next)
            }
        }
    }

    private func button(_ symbol: String, _ command: MediaCommand, size: CGFloat = 12) -> some View {
        Button { onCommand(command) } label: {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
