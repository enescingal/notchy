import CoreGraphics

enum NotchLayout {
    /// Inward-curved top corners drawn outside the physical notch on both sides.
    static let earRadius: CGFloat = 6
    static let peekSideWidth: CGFloat = 110
    static let mediaIndicatorWidth: CGFloat = 32
    static let expandedSideWidth: CGFloat = 120
    static let expandedMinWidth: CGFloat = 460
    static let expandedExtraHeight: CGFloat = 104
    static let panelMargin: CGFloat = 24

    static func islandSize(for state: NotchState, isMediaPlaying: Bool, notch: CGSize) -> CGSize {
        let body: CGSize
        switch state {
        case .closed:
            body = isMediaPlaying
                ? CGSize(width: notch.width + 2 * mediaIndicatorWidth, height: notch.height)
                : notch
        case .peek:
            body = CGSize(width: notch.width + 2 * peekSideWidth, height: notch.height)
        case .expanded:
            body = CGSize(width: max(notch.width + 2 * expandedSideWidth, expandedMinWidth),
                          height: notch.height + expandedExtraHeight)
        }
        return CGSize(width: body.width + 2 * earRadius, height: body.height)
    }

    static func panelSize(notch: CGSize) -> CGSize {
        let expanded = islandSize(for: .expanded, isMediaPlaying: false, notch: notch)
        return CGSize(width: expanded.width + 2 * panelMargin, height: expanded.height + panelMargin)
    }

    /// Island rect in panel-local AppKit coordinates (origin bottom-left).
    static func islandRect(islandSize: CGSize, panelSize: CGSize) -> CGRect {
        CGRect(x: (panelSize.width - islandSize.width) / 2,
               y: panelSize.height - islandSize.height,
               width: islandSize.width,
               height: islandSize.height)
    }
}
