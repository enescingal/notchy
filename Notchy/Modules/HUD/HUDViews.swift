import SwiftUI

struct HUDPeekView: View {
    let hud: HUDState
    let notchWidth: CGFloat
    var sideWidth: CGFloat = NotchLayout.peekSideWidth

    var body: some View {
        PeekLayout(notchWidth: notchWidth, sideWidth: sideWidth) {
            Image(systemName: Self.symbolName(for: hud))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        } right: {
            LevelBar(level: hud.isMuted ? 0 : hud.level)
                .frame(width: 70, height: 6)
        }
    }

    static func symbolName(for hud: HUDState) -> String {
        switch hud.kind {
        case .brightness:
            return hud.level < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .volume:
            if hud.isMuted || hud.level == 0 { return "speaker.slash.fill" }
            if hud.level < 0.33 { return "speaker.wave.1.fill" }
            if hud.level < 0.66 { return "speaker.wave.2.fill" }
            return "speaker.wave.3.fill"
        }
    }
}

struct LevelBar: View {
    let level: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.2))
                Capsule().fill(Color.white)
                    .frame(width: geo.size.width * CGFloat(min(max(level, 0), 1)))
            }
        }
        .animation(.easeOut(duration: 0.12), value: level)
    }
}
