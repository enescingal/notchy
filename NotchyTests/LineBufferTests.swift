import XCTest
@testable import Notchy

final class LineBufferTests: XCTestCase {
    func testSplitsCompleteLinesAndKeepsRemainder() {
        var buffer = LineBuffer()
        XCTAssertEqual(buffer.append(Data("a\nb".utf8)), ["a"])
        XCTAssertEqual(buffer.append(Data("c\n\nd\n".utf8)), ["bc", "d"])
    }

    func testMultiByteCharacterSplitAcrossChunks() {
        var buffer = LineBuffer()
        let bytes = Array("Şarkı\n".utf8)
        XCTAssertEqual(buffer.append(Data(bytes[0..<1])), [])
        XCTAssertEqual(buffer.append(Data(bytes[1...])), ["Şarkı"])
    }
}
