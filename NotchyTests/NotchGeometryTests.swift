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
        func size(_ state: NotchState, _ content: IslandContent) -> CGSize {
            NotchLayout.islandSize(for: state, content: content, notch: notch)
        }
        XCTAssertEqual(size(.closed, IslandContent()), CGSize(width: 212, height: 32))
        XCTAssertEqual(size(.closed, IslandContent(isMediaPlaying: true, hasMedia: true)), CGSize(width: 276, height: 32))
        XCTAssertEqual(size(.closed, IslandContent(hasCountdown: true)), CGSize(width: 364, height: 32))
        XCTAssertEqual(size(.peek(Fixtures.pluggedIn), IslandContent()), CGSize(width: 432, height: 32))
        XCTAssertEqual(size(.expanded, IslandContent()), CGSize(width: 392, height: 80))
        XCTAssertEqual(size(.expanded, IslandContent(hasMedia: true)), CGSize(width: 392, height: 116))
        XCTAssertEqual(size(.expanded, IslandContent(isEditingCountdown: true)), CGSize(width: 392, height: 116))
        XCTAssertEqual(size(.expanded, IslandContent(hasMedia: true, hasCountdown: true)), CGSize(width: 392, height: 152))
    }

    func testPanelSizeFitsExpandedIslandWithMargin() {
        XCTAssertEqual(NotchLayout.panelSize(notch: notch), CGSize(width: 440, height: 176))
    }

    func testExpandedSideSpaceFitsTheHUDBesideTheNotch() {
        XCTAssertEqual(NotchLayout.expandedSideSpace(notch: notch), 90)
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
        func hidden(_ state: NotchState, _ content: IslandContent, virtual: Bool = true) -> Bool {
            NotchLayout.isHidden(state: state, content: content, isVirtualNotch: virtual)
        }
        XCTAssertTrue(hidden(.closed, IslandContent()))
        XCTAssertFalse(hidden(.closed, IslandContent(isMediaPlaying: true, hasMedia: true)))
        XCTAssertFalse(hidden(.closed, IslandContent(hasCountdown: true)))
        XCTAssertFalse(hidden(.expanded, IslandContent()))
        XCTAssertFalse(hidden(.peek(Fixtures.pluggedIn), IslandContent()))
        XCTAssertFalse(hidden(.closed, IslandContent(), virtual: false))
    }
}
