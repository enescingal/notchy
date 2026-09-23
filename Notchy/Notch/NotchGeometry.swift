import CoreGraphics

/// Where the island sits on one screen: over the physical notch, or over a virtual notch
/// at the top center of a screen that has none.
struct NotchPlacement: Equatable {
    var size: CGSize
    var isVirtual: Bool
}

enum NotchGeometry {
    /// Virtual notch width, the same as the MacBook Pro notch.
    static let virtualNotchWidth: CGFloat = 185
    /// Virtual notch height when the screen shows no menu bar (auto-hidden, or none on that display).
    static let fallbackMenuBarHeight: CGFloat = 24

    /// Physical notch size in points, or nil when the screen has no notch.
    static func notchSize(screenWidth: CGFloat, safeAreaTop: CGFloat,
                          leftAuxiliaryWidth: CGFloat?, rightAuxiliaryWidth: CGFloat?) -> CGSize? {
        guard safeAreaTop > 0, let left = leftAuxiliaryWidth, let right = rightAuxiliaryWidth else { return nil }
        let width = screenWidth - left - right
        guard width > 0 else { return nil }
        return CGSize(width: width, height: safeAreaTop)
    }

    /// The physical notch when the screen has one, otherwise a virtual notch as tall as the menu bar.
    static func placement(screenWidth: CGFloat, safeAreaTop: CGFloat,
                          leftAuxiliaryWidth: CGFloat?, rightAuxiliaryWidth: CGFloat?,
                          menuBarHeight: CGFloat) -> NotchPlacement {
        if let size = notchSize(screenWidth: screenWidth, safeAreaTop: safeAreaTop,
                                leftAuxiliaryWidth: leftAuxiliaryWidth, rightAuxiliaryWidth: rightAuxiliaryWidth) {
            return NotchPlacement(size: size, isVirtual: false)
        }
        let height = menuBarHeight > 0 ? menuBarHeight : fallbackMenuBarHeight
        return NotchPlacement(size: CGSize(width: virtualNotchWidth, height: height), isVirtual: true)
    }

    /// Index of the screen frame containing `point`. The top edge (y == maxY) counts as inside,
    /// because the mouse can sit on the very top pixel row.
    static func screenIndex(containing point: CGPoint, in frames: [CGRect]) -> Int? {
        frames.firstIndex { frame in
            point.x >= frame.minX && point.x < frame.maxX && point.y >= frame.minY && point.y <= frame.maxY
        }
    }

    /// Horizontally centered, touching the top edge (AppKit screen coordinates).
    static func panelFrame(screenFrame: CGRect, panelSize: CGSize) -> CGRect {
        CGRect(x: screenFrame.midX - panelSize.width / 2,
               y: screenFrame.maxY - panelSize.height,
               width: panelSize.width,
               height: panelSize.height)
    }
}
