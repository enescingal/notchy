import CoreGraphics

enum NotchGeometry {
    /// Physical notch size in points, or nil when the screen has no notch.
    static func notchSize(screenWidth: CGFloat, safeAreaTop: CGFloat,
                          leftAuxiliaryWidth: CGFloat?, rightAuxiliaryWidth: CGFloat?) -> CGSize? {
        guard safeAreaTop > 0, let left = leftAuxiliaryWidth, let right = rightAuxiliaryWidth else { return nil }
        let width = screenWidth - left - right
        guard width > 0 else { return nil }
        return CGSize(width: width, height: safeAreaTop)
    }

    /// Horizontally centered, touching the top edge (AppKit screen coordinates).
    static func panelFrame(screenFrame: CGRect, panelSize: CGSize) -> CGRect {
        CGRect(x: screenFrame.midX - panelSize.width / 2,
               y: screenFrame.maxY - panelSize.height,
               width: panelSize.width,
               height: panelSize.height)
    }
}
