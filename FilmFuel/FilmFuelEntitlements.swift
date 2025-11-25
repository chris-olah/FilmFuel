//
//  FilmFuelEntitlements.swift
//  FilmFuel
//
//  Central place for what is free vs FilmFuel+.
//

import Foundation
import Combine

@MainActor
final class FilmFuelEntitlements: ObservableObject {

    // MARK: - Plus state

    @Published var isPlus: Bool = false {
        didSet {
            if isPlus {
                // If they become Plus, you can reset Smart Mode limits or ignore them.
                // We'll just reset so if they ever downgrade you have a sane baseline.
                freeSmartUsesRemainingToday = maxFreeSmartUsesPerDay
                saveSmartUses()
            }
        }
    }

    // MARK: - Free Smart Mode uses per day

    private let smartUsesKey = "ff.freeSmartUsesRemaining"
    private let smartUsesDateKey = "ff.freeSmartUsesDate"

    /// Maximum free Smart Mode toggles per day on the free tier.
    let maxFreeSmartUsesPerDay = 2

    /// How many Smart Mode uses the free user has left *today*.
    @Published var freeSmartUsesRemainingToday: Int

    init() {
        // Default to full allowance until we read from disk
        self.freeSmartUsesRemainingToday = maxFreeSmartUsesPerDay
        loadSmartUses()
    }

    // MARK: - Smart Mode helpers

    /// Whether the user is allowed to attempt Smart Mode right now.
    func canUseSmartMode() -> Bool {
        if isPlus { return true }
        return freeSmartUsesRemainingToday > 0
    }

    /// Call this when a free user actually *uses* Smart Mode.
    /// Returns true if it was allowed and decremented, false if they hit the limit.
    @discardableResult
    func consumeFreeSmartModeUseIfNeeded() -> Bool {
        // Plus users are unrestricted
        if isPlus { return true }

        guard freeSmartUsesRemainingToday > 0 else {
            return false
        }

        freeSmartUsesRemainingToday -= 1
        saveSmartUses()
        return true
    }

    // MARK: - Trivia entitlements

    var canAccessAllTriviaPacks: Bool {
        isPlus
    }

    var canUseUnlimitedTrivia: Bool {
        isPlus
    }

    // MARK: - Persistence

    /// Load or reset today's Smart Mode uses from UserDefaults.
    private func loadSmartUses() {
        let defaults = UserDefaults.standard
        let today = Self.todayString()

        if let storedDate = defaults.string(forKey: smartUsesDateKey),
           storedDate == today {
            // Same day → use stored value, clamped into a safe range.
            let remaining = defaults.integer(forKey: smartUsesKey)
            freeSmartUsesRemainingToday = max(0, min(remaining, maxFreeSmartUsesPerDay))
        } else {
            // New day → reset full allowance and write it out.
            freeSmartUsesRemainingToday = maxFreeSmartUsesPerDay
            defaults.set(today, forKey: smartUsesDateKey)
            defaults.set(freeSmartUsesRemainingToday, forKey: smartUsesKey)
        }
    }

    /// Save current remaining uses + associate it with "today".
    private func saveSmartUses() {
        let defaults = UserDefaults.standard
        defaults.set(Self.todayString(), forKey: smartUsesDateKey)
        defaults.set(freeSmartUsesRemainingToday, forKey: smartUsesKey)
    }

    /// Simple "yyyy-MM-dd" day stamp used to reset the daily allowance.
    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
