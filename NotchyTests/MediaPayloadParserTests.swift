import XCTest
@testable import Notchy

final class MediaPayloadParserTests: XCTestCase {
    func testFullPayload() {
        let line = #"{"type":"data","diff":false,"payload":{"title":"Song","artist":"Artist","playing":true,"bundleIdentifier":"com.spotify.client","album":""}}"#
        XCTAssertEqual(MediaPayloadParser.parse(line),
                       .update(MediaState(title: "Song", artist: "Artist", isPlaying: true, bundleIdentifier: "com.spotify.client")))
    }

    func testEmptyPayloadMeansNothingPlaying() {
        XCTAssertEqual(MediaPayloadParser.parse(#"{"type":"data","diff":false,"payload":{}}"#), .update(nil))
    }

    func testMissingTitleMeansNothingPlaying() {
        XCTAssertEqual(MediaPayloadParser.parse(#"{"type":"data","payload":{"artist":"A","playing":true}}"#), .update(nil))
    }

    func testEmptyArtistBecomesNilAndMissingPlayingIsFalse() {
        XCTAssertEqual(MediaPayloadParser.parse(#"{"type":"data","payload":{"title":"T","artist":""}}"#),
                       .update(MediaState(title: "T", artist: nil, isPlaying: false, bundleIdentifier: nil)))
    }

    func testOtherTypesAndGarbageAreIgnored() {
        XCTAssertEqual(MediaPayloadParser.parse(#"{"type":"status"}"#), .ignored)
        XCTAssertEqual(MediaPayloadParser.parse("not json"), .ignored)
    }
}
