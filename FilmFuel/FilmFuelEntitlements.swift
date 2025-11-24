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
                freeSmartUsesRemainingToday = maxFreeSmartUsesPerDay
                saveSmartUses()
            }
        }
    }

    // MARK: - Free Smart Mode uses per day

    private let smartUsesKey = "ff.freeSmartUsesRemaining"
    private let smartUsesDateKey = "ff.freeSmartUsesDate"

    let maxFreeSmartUsesPerDay = 3

    @Published var freeSmartUsesRemainingToday: Int = 3

    init() {
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

    private func loadSmartUses() {
        let defaults = UserDefaults.standard
        let today = Self.todayString()

        if let storedDate = defaults.string(forKey: smartUsesDateKey),
           storedDate == today {
            let remaining = defaults.integer(forKey: smartUsesKey)
            if remaining > 0 {
                freeSmartUsesRemainingToday = remaining
            } else {
                freeSmartUsesRemainingToday = 0
            }
        } else {
            // New day → reset
            freeSmartUsesRemainingToday = maxFreeSmartUsesPerDay
            defaults.set(today, forKey: smartUsesDateKey)
            defaults.set(freeSmartUsesRemainingToday, forKey: smartUsesKey)
        }
    }

    private func saveSmartUses() {
        let defaults = UserDefaults.standard
        defaults.set(Self.todayString(), forKey: smartUsesDateKey)
        defaults.set(freeSmartUsesRemainingToday, forKey: smartUsesKey)
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
