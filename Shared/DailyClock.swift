import Foundation

/// Groups time into “days” that start at 3:00 AM local time.
/// e.g. anything before 3:00 counts as "yesterday" for the app.
enum DailyClock {
    private static let anchorHour = 3  // 3 AM local

    static func currentDayKey() -> String {
        dayKey(for: Date())
    }

    static func dayKey(offsetDays: Int) -> String {
        let now = Date()
        let cal = Calendar.current
        let shifted = cal.date(byAdding: .day, value: offsetDays, to: now) ?? now
        return dayKey(for: shifted)
    }

    static func dayKey(for date: Date) -> String {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date)
        comps.hour = anchorHour; comps.minute = 0; comps.second = 0
        let anchorToday = cal.date(from: comps)!

        let effectiveDayStart: Date =
            (date < anchorToday) ? cal.date(byAdding: .day, value: -1, to: anchorToday)! : anchorToday

        let parts = cal.dateComponents([.year, .month, .day], from: effectiveDayStart)
        let y = parts.year!, m = parts.month!, d = parts.day!
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}

