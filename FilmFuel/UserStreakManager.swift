//
//  UserStreakManager.swift
//  FilmFuel
//

import Foundation

struct UserStreak {
    let current: Int
    let best: Int
}

enum UserStreakManager {
    private static let currentKey = "ff.streak.current"
    private static let bestKey = "ff.streak.best"
    private static let lastDateKey = "ff.streak.lastDate"

    /// Bumps the streak for "today" and returns the current streak info.
    @discardableResult
    static func bumpForToday() -> UserStreak {
        let defaults = UserDefaults.standard
        let today = Self.dayString(from: Date())

        let lastDate = defaults.string(forKey: lastDateKey)
        var current = defaults.integer(forKey: currentKey)
        var best = defaults.integer(forKey: bestKey)

        if let lastDate, lastDate == today {
            // Already counted today; just return existing values (or initialize if 0)
            if current == 0 {
                current = 1
            }
        } else if let lastDate,
                  let last = dayDate(from: lastDate),
                  let todayDate = dayDate(from: today) {
            let diff = Calendar.current.dateComponents([.day], from: last, to: todayDate).day ?? 0
            if diff == 1 {
                // Consecutive day → increment
                current += 1
            } else if diff > 1 {
                // Gap → reset to 1
                current = 1
            } else {
                // Same or negative diff (clock weirdness) → at least 1
                current = max(current, 1)
            }
        } else {
            // First time opening Discover
            current = max(current, 1)
        }

        if current > best {
            best = current
        }

        defaults.set(current, forKey: currentKey)
        defaults.set(best, forKey: bestKey)
        defaults.set(today, forKey: lastDateKey)

        return UserStreak(current: current, best: best)
    }

    // MARK: - Helpers

    private static func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func dayDate(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
