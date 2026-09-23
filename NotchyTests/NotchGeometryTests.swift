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
        XCTAssertEqual(NotchLayout.islandSize(for: .closed, isMediaPlaying: false, hasMedia: false, notch: notch), CGSize(width: 212, height: 32))
        XCTAssertEqual(NotchLayout.islandSize(for: .closed, isMediaPlaying: true, hasMedia: false, notch: notch), CGSize(width: 276, height: 32))
        XCTAssertEqual(NotchLayout.islandSize(for: .peek(Fixtures.pluggedIn), isMediaPlaying: false, hasMedia: false, notch: notch), CGSize(width: 432, height: 32))
        XCTAssertEqual(NotchLayout.islandSize(for: .expanded, isMediaPlaying: false, hasMedia: false, notch: notch), CGSize(width: 472, height: 80))
        XCTAssertEqual(NotchLayout.islandSize(for: .expanded, isMediaPlaying: false, hasMedia: true, notch: notch), CGSize(width: 472, height: 116))
    }

    func testPanelSizeFitsExpandedIslandWithMargin() {
        XCTAssertEqual(NotchLayout.panelSize(notch: notch), CGSize(width: 520, height: 140))
    }

    func testIslandRectIsTopCenteredInPanel() {
        let rect = NotchLayout.islandRect(islandSize: CGSize(width: 212, height: 32), panelSize: CGSize(width: 520, height: 160))
        XCTAssertEqual(rect, CGRect(x: 154, y: 128, width: 212, height: 32))
    }

    func testPlacementUsesThePhysicalNotch() {
        let placement = NotchGeometry.placement(screenWidth: 1512, safeAreaTop: 32, leftAuxiliaryWidth: 663.5,
                                                rightAuxiliaryWidth: 663.5, menuBarHeight: 32)
        XCTAssertEqual(placement, NotchPlacement(size: CGSize(width: 185, height: 32), isVirtual: false))
    }

    func testPlacementUsesAVirtualNotchAsTallAsTheMenuBar() {
        let placement = NotchGeometry.placement(screenWidth: 2560, safeAreaTop: 0, leftAuxiliaryWidth: nil,
                                                rightAuxiliaryWidth: nil, menuBarHeight: 31)
        XCTAssertEqual(placement, NotchPlacement(size: CGSize(width: 185, height: 31), isVirtual: true))
    }

    func testVirtualNotchFallsBackTo24PointsWithoutAMenuBar() {
        let placement = NotchGeometry.placement(screenWidth: 2560, safeAreaTop: 0, leftAuxiliaryWidth: nil,
                                                rightAuxiliaryWidth: nil, menuBarHeight: 0)
        XCTAssertEqual(placement, NotchPlacement(size: CGSize(width: 185, height: 24), isVirtual: true))
    }

    func testScreenIndexFindsTheScreenUnderThePoint() {
        let frames = [CGRect(x: 0, y: 0, width: 2560, height: 1440),
                      CGRect(x: 2560, y: 211, width: 1512, height: 982)]
        XCTAssertEqual(NotchGeometry.screenIndex(containing: CGPoint(x: 100, y: 100), in: frames), 0)
        XCTAssertEqual(NotchGeometry.screenIndex(containing: CGPoint(x: 3000, y: 500), in: frames), 1)
        XCTAssertEqual(NotchGeometry.screenIndex(containing: CGPoint(x: 2560, y: 500), in: frames), 1)
        XCTAssertEqual(NotchGeometry.screenIndex(containing: CGPoint(x: 100, y: 1440), in: frames), 0, "top edge counts")
        XCTAssertNil(NotchGeometry.screenIndex(containing: CGPoint(x: 3000, y: 100), in: frames))
    }

    func testIdleIslandIsHiddenOnlyOnAVirtualNotch() {
        XCTAssertTrue(NotchLayout.isHidden(state: .closed, isMediaPlaying: false, isVirtualNotch: true))
        XCTAssertFalse(NotchLayout.isHidden(state: .closed, isMediaPlaying: true, isVirtualNotch: true))
        XCTAssertFalse(NotchLayout.isHidden(state: .expanded, isMediaPlaying: false, isVirtualNotch: true))
        XCTAssertFalse(NotchLayout.isHidden(state: .peek(Fixtures.pluggedIn), isMediaPlaying: false, isVirtualNotch: true))
        XCTAssertFalse(NotchLayout.isHidden(state: .closed, isMediaPlaying: false, isVirtualNotch: false))
    }
}
