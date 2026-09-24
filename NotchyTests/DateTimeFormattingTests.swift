import XCTest
@testable import Notchy

final class DateTimeFormattingTests: XCTestCase {
    private let istanbul = TimeZone(identifier: "Europe/Istanbul")!

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = istanbul
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testDateTextIsShortTurkish() {
        XCTAssertEqual(DateTimeStripView.dateText(date(2026, 9, 24, 9, 5), timeZone: istanbul), "24 Eyl Per")
        XCTAssertEqual(DateTimeStripView.dateText(date(2026, 2, 25, 9, 5), timeZone: istanbul), "25 Şub Çar")
    }

    func testTimeTextIs24Hour() {
        XCTAssertEqual(DateTimeStripView.timeText(date(2026, 9, 24, 9, 5), timeZone: istanbul), "09:05")
        XCTAssertEqual(DateTimeStripView.timeText(date(2026, 9, 24, 21, 40), timeZone: istanbul), "21:40")
    }
}
