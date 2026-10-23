import Foundation

/// A Gregorian calendar day handled as plain integers, so date arithmetic never depends on the
/// device time zone. Mirrors the `YYYY-MM-DD` strings the Godot version passes around.
public struct CivilDate: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Strict `YYYY-MM-DD` parser with the same rules as `events.gd::_valid_date`.
    public init?(_ text: String) {
        let chars = Array(text.unicodeScalars)
        guard chars.count == 10, chars[4] == "-", chars[7] == "-" else { return nil }
        for i in [0, 1, 2, 3, 5, 6, 8, 9] where !("0"..."9").contains(chars[i]) { return nil }
        let digits = text.split(separator: "-").compactMap { Int($0) }
        guard digits.count == 3 else { return nil }
        let (year, month, day) = (digits[0], digits[1], digits[2])
        guard year >= 1970, (1...12).contains(month), day >= 1, day <= CivilDate.length(year: year, month: month) else { return nil }
        self.init(year: year, month: month, day: day)
    }

    public static func isLeap(_ year: Int) -> Bool {
        year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    }

    public static func length(year: Int, month: Int) -> Int {
        [31, isLeap(year) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
    }

    public var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    /// `MM-DD`, the key of the daily program table.
    public var monthDay: String { String(format: "%02d-%02d", month, day) }

    /// Days since 1970-01-01 (Howard Hinnant's days_from_civil).
    public var daysSinceEpoch: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }

    public init(daysSinceEpoch z0: Int) {
        let z = z0 + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let day = doy - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        self.init(year: yoe + era * 400 + (month <= 2 ? 1 : 0), month: month, day: day)
    }

    public func adding(days: Int) -> CivilDate { CivilDate(daysSinceEpoch: daysSinceEpoch + days) }

    /// 0 = Sunday, like Godot's `weekday`.
    public var weekday: Int { ((daysSinceEpoch + 4) % 7 + 7) % 7 }

    public static func < (a: CivilDate, b: CivilDate) -> Bool { a.daysSinceEpoch < b.daysSinceEpoch }

    /// The calendar day at a fixed UTC offset (the weather city's offset).
    public static func at(_ date: Date, utcOffset: Int) -> CivilDate {
        let seconds = Int(date.timeIntervalSince1970.rounded(.down)) + utcOffset
        return CivilDate(daysSinceEpoch: Int((Double(seconds) / 86400).rounded(.down)))
    }

    /// The calendar day in the device's own time zone.
    public static func local(_ date: Date = Date(), timeZone: TimeZone = .current) -> CivilDate {
        at(date, utcOffset: timeZone.secondsFromGMT(for: date))
    }
}
