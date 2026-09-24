import SwiftUI

/// Date left of the notch and time right of it, on the expanded island's top strip.
struct DateTimeStripView: View {
    let notchWidth: CGFloat
    let sideWidth: CGFloat

    var body: some View {
        TimelineView(.everyMinute) { context in
            PeekLayout(notchWidth: notchWidth, sideWidth: sideWidth) {
                Text(Self.dateText(context.date))
            } right: {
                Text(Self.timeText(context.date))
            }
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
        }
    }

    /// Turkish like the rest of the island, whatever the system language: "24 Eyl Per".
    static func dateText(_ date: Date, timeZone: TimeZone = .current) -> String {
        format(date, "d MMM EEE", timeZone: timeZone)
    }

    static func timeText(_ date: Date, timeZone: TimeZone = .current) -> String {
        format(date, "HH:mm", timeZone: timeZone)
    }

    private static func format(_ date: Date, _ pattern: String, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
