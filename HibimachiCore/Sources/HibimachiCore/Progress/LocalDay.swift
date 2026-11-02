import Foundation

/// A calendar day in the player's time zone. Quests are "done today" per local day, while timestamps stay UTC
/// (DATA-MODEL: separate UTC time from the local date to survive time-zone changes and DST).
public struct LocalDay: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// Parses "yyyy-MM-dd" (the stored form).
    public init?(string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Stable per-day seed for the quest planner, so suggestions do not reshuffle during a day.
    var seed: UInt64 {
        UInt64(year) &* 10_000 &+ UInt64(month) &* 100 &+ UInt64(day)
    }

    /// A fixed Gregorian calendar in UTC: counting days must not depend on the device's settings.
    private static let dayCounting: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    /// Whole days from `other` to this day (negative when `other` is later).
    public func daysSince(_ other: LocalDay) -> Int {
        let calendar = Self.dayCounting
        guard
            let start = calendar.date(from: DateComponents(year: other.year, month: other.month, day: other.day)),
            let end = calendar.date(from: DateComponents(year: year, month: month, day: day))
        else { return 0 }
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    public static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
