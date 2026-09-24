import SwiftUI

/// Puts content left and right of the physical notch, leaving the notch itself empty.
struct PeekLayout<Left: View, Right: View>: View {
    let notchWidth: CGFloat
    /// Room on each side; the expanded island is narrower than a peek.
    var sideWidth: CGFloat = NotchLayout.peekSideWidth
    @ViewBuilder var left: Left
    @ViewBuilder var right: Right

    var body: some View {
        HStack(spacing: 0) {
            left
                .padding(.leading, NotchLayout.contentInset)
                .frame(width: sideWidth + NotchLayout.earRadius, alignment: .leading)
            Color.clear.frame(width: notchWidth)
            right
                .padding(.trailing, NotchLayout.contentInset)
                .frame(width: sideWidth + NotchLayout.earRadius, alignment: .trailing)
        }
        .frame(maxHeight: .infinity)
    }
}
