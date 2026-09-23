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

struct MediaExpandedView: View {
    let media: MediaState
    let onCommand: (MediaCommand) -> Void

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text(media.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let artist = media.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            HStack(spacing: 28) {
                button("backward.fill", .previous)
                button(media.isPlaying ? "pause.fill" : "play.fill", .togglePlayPause, size: 20)
                button("forward.fill", .next)
            }
        }
    }

    private func button(_ symbol: String, _ command: MediaCommand, size: CGFloat = 16) -> some View {
        Button { onCommand(command) } label: {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
