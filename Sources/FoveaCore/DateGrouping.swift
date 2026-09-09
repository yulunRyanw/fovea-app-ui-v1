import Foundation

public struct DateGroup: Identifiable, Hashable, Sendable {
    public let id: String
    /// "Today", "Yesterday", or "Sep 3, 2024".
    public let title: String
    /// Calendar date shown beside Today/Yesterday; nil for older dates.
    public let subtitle: String?
    public let captures: [Capture]
}

public enum DateGrouping {
    public static func groups(_ captures: [Capture], now: Date = Date(),
                              calendar: Calendar = .current) -> [DateGroup] {
        let sorted = captures.sorted { $0.createdAt > $1.createdAt }
        var order: [Date] = []
        var byDay: [Date: [Capture]] = [:]
        for c in sorted {
            let day = calendar.startOfDay(for: c.createdAt)
            if byDay[day] == nil { order.append(day) }
            byDay[day, default: []].append(c)
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM d, yyyy"
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        return order.map { day in
            let dateText = formatter.string(from: day)
            if day == today {
                return DateGroup(id: "today", title: "Today", subtitle: dateText, captures: byDay[day] ?? [])
            } else if day == yesterday {
                return DateGroup(id: "yesterday", title: "Yesterday", subtitle: dateText, captures: byDay[day] ?? [])
            }
            return DateGroup(id: dateText, title: dateText, subtitle: nil, captures: byDay[day] ?? [])
        }
    }

    public static func timeLabel(_ date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    public static func fullLabel(_ date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "EEEE, MMM d, yyyy 'at' h:mm a"
        return f.string(from: date)
    }

    /// Metadata-bar timestamp: "Sep 7, 2026 · 10:24 AM".
    public static func detailLabel(_ date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy · h:mm a"
        return f.string(from: date)
    }

    public static func shortDate(_ date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}
