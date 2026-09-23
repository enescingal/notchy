import XCTest
@testable import Notchy

@MainActor
final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suiteName = "NotchyTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaults() {
        let store = SettingsStore(defaults: defaults)
        for id in ModuleID.allCases { XCTAssertTrue(store.isEnabled(id), "\(id)") }
        XCTAssertEqual(store.hoverDelay, 0.1)
        XCTAssertEqual(store.peekDuration, 3.0)
        XCTAssertFalse(store.hasCompletedOnboarding)
    }

    func testValuesPersist() {
        let store = SettingsStore(defaults: defaults)
        store.batteryEnabled = false
        store.peekDuration = 4.5
        store.hasCompletedOnboarding = true

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertFalse(reloaded.isEnabled(.battery))
        XCTAssertTrue(reloaded.isEnabled(.media))
        XCTAssertEqual(reloaded.peekDuration, 4.5)
        XCTAssertTrue(reloaded.hasCompletedOnboarding)
    }

    func testNotchConfiguration() {
        let store = SettingsStore(defaults: defaults)
        store.hoverDelay = 0.25
        store.peekDuration = 2
        let config = store.notchConfiguration
        XCTAssertEqual(config.hoverDelay, 0.25)
        XCTAssertEqual(config.peekDuration, 2)
        XCTAssertEqual(config.hudDuration, 1.5)
        XCTAssertEqual(config.collapseDelay, 0.3)
    }
}
