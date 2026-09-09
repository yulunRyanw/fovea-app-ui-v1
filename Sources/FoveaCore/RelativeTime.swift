import Foundation

/// Short relative times for the Island's Chat lists: "12m", "2h", "yesterday", "Sep 5".
public enum RelativeTime {
    /// "now" under a minute, minutes under an hour, hours under a day, "yesterday", then
    /// a short date (with the year once it differs).
    public static func short(from date: Date, to now: Date, calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 24 * 3600 { return "\(Int(seconds / 3600))h" }
        if calendar.isDateInYesterday(date) || isYesterday(date, now: now, calendar: calendar) { return "yesterday" }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = sameYear ? "MMM d" : "MMM d, yyyy"
        return formatter.string(from: date)
    }

    /// Search rows: "Active 9h ago" within a day, otherwise the short form.
    public static func activity(from date: Date, to now: Date, calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(date)
        guard seconds < 24 * 3600 else { return short(from: date, to: now, calendar: calendar) }
        if seconds < 60 { return "Active just now" }
        return "Active \(short(from: date, to: now, calendar: calendar)) ago"
    }

    /// `isDateInYesterday` compares with the real clock; tests pass their own `now`.
    private static func isYesterday(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return false }
        return calendar.isDate(date, inSameDayAs: yesterday)
    }
}
