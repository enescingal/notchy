import CoreGraphics

/// What the island shows besides its state; drives its size.
struct IslandContent: Equatable {
    var isMediaPlaying = false
    var hasMedia = false
    var hasCountdown = false
    var isEditingCountdown = false

    /// Rows under the notch while expanded: controls, then countdown, then media.
    var expandedRows: Int {
        1 + (hasCountdown || isEditingCountdown ? 1 : 0) + (hasMedia ? 1 : 0)
    }
}

enum NotchLayout {
    /// Inward-curved top corners drawn outside the physical notch on both sides.
    static let earRadius: CGFloat = 6
    static let peekSideWidth: CGFloat = 110
    static let mediaIndicatorWidth: CGFloat = 32
    static let expandedSideWidth: CGFloat = 90
    static let expandedMinWidth: CGFloat = 380
    static let expandedExtraHeight: CGFloat = 48
    /// Extra height for each row under the control row (countdown, media).
    static let expandedRowHeight: CGFloat = 36
    static let countdownSideWidth: CGFloat = 76
    static let panelMargin: CGFloat = 24

    static func islandSize(for state: NotchState, content: IslandContent, notch: CGSize) -> CGSize {
        let body: CGSize
        switch state {
        case .closed:
            let side = content.hasCountdown ? countdownSideWidth
                : content.isMediaPlaying ? mediaIndicatorWidth : 0
            body = CGSize(width: notch.width + 2 * side, height: notch.height)
        case .peek:
            body = CGSize(width: notch.width + 2 * peekSideWidth, height: notch.height)
        case .expanded:
            body = CGSize(width: notch.width + 2 * expandedSideSpace(notch: notch),
                          height: notch.height + expandedExtraHeight
                              + CGFloat(content.expandedRows - 1) * expandedRowHeight)
        }
        return CGSize(width: body.width + 2 * earRadius, height: body.height)
    }

    /// Room on each side of the notch in the expanded island, not counting the ear corners.
    static func expandedSideSpace(notch: CGSize) -> CGFloat {
        (max(notch.width + 2 * expandedSideWidth, expandedMinWidth) - notch.width) / 2
    }

    static func panelSize(notch: CGSize) -> CGSize {
        let tallest = IslandContent(isMediaPlaying: true, hasMedia: true, hasCountdown: true)
        let expanded = islandSize(for: .expanded, content: tallest, notch: notch)
        return CGSize(width: expanded.width + 2 * panelMargin, height: expanded.height + panelMargin)
    }

    /// Island rect in panel-local AppKit coordinates (origin bottom-left).
    static func islandRect(islandSize: CGSize, panelSize: CGSize) -> CGRect {
        CGRect(x: (panelSize.width - islandSize.width) / 2,
               y: panelSize.height - islandSize.height,
               width: islandSize.width,
               height: islandSize.height)
    }

    /// On a screen without a physical notch the idle island is not drawn; its area still detects hover.
    static func isHidden(state: NotchState, content: IslandContent, isVirtualNotch: Bool) -> Bool {
        isVirtualNotch && state == .closed && !content.isMediaPlaying && !content.hasCountdown
    }
}
