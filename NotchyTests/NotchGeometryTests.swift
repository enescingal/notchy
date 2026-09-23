import XCTest
@testable import Notchy

final class NotchGeometryTests: XCTestCase {
    private let notch = CGSize(width: 200, height: 32)

    func testNotchSizeFromAuxiliaryAreas() {
        let size = NotchGeometry.notchSize(screenWidth: 1512, safeAreaTop: 32, leftAuxiliaryWidth: 656, rightAuxiliaryWidth: 656)
        XCTAssertEqual(size, CGSize(width: 200, height: 32))
    }

    func testNoNotchWhenSafeAreaIsZero() {
        XCTAssertNil(NotchGeometry.notchSize(screenWidth: 1512, safeAreaTop: 0, leftAuxiliaryWidth: 656, rightAuxiliaryWidth: 656))
    }

    func testNoNotchWhenAuxiliaryAreasMissing() {
        XCTAssertNil(NotchGeometry.notchSize(screenWidth: 1512, safeAreaTop: 32, leftAuxiliaryWidth: nil, rightAuxiliaryWidth: 656))
    }

    func testPanelFrameIsCenteredAtTop() {
        let frame = NotchGeometry.panelFrame(screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), panelSize: CGSize(width: 520, height: 160))
        XCTAssertEqual(frame, CGRect(x: 496, y: 822, width: 520, height: 160))
    }

    func testIslandSizes() {
        XCTAssertEqual(NotchLayout.islandSize(for: .closed, isMediaPlaying: false, notch: notch), CGSize(width: 212, height: 32))
        XCTAssertEqual(NotchLayout.islandSize(for: .closed, isMediaPlaying: true, notch: notch), CGSize(width: 276, height: 32))
        XCTAssertEqual(NotchLayout.islandSize(for: .peek(Fixtures.pluggedIn), isMediaPlaying: false, notch: notch), CGSize(width: 432, height: 32))
        XCTAssertEqual(NotchLayout.islandSize(for: .expanded, isMediaPlaying: false, notch: notch), CGSize(width: 472, height: 80))
    }

    func testPanelSizeFitsExpandedIslandWithMargin() {
        XCTAssertEqual(NotchLayout.panelSize(notch: notch), CGSize(width: 520, height: 104))
    }

    func testIslandRectIsTopCenteredInPanel() {
        let rect = NotchLayout.islandRect(islandSize: CGSize(width: 212, height: 32), panelSize: CGSize(width: 520, height: 160))
        XCTAssertEqual(rect, CGRect(x: 154, y: 128, width: 212, height: 32))
    }
}
