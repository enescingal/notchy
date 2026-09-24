import XCTest
@testable import Notchy

final class MediaTitleTests: XCTestCase {
    func testArtistSuffix() {
        XCTAssertEqual(MediaExpandedView.artistSuffix("Artist"), " (Artist)")
        XCTAssertNil(MediaExpandedView.artistSuffix(nil))
        XCTAssertNil(MediaExpandedView.artistSuffix(""))
        XCTAssertNil(MediaExpandedView.artistSuffix("  "))
    }
}
