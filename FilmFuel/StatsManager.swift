//
//  StatsManager.swift
//  FilmFuel
//

import Foundation
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

final class StatsManager {

    static let shared = StatsManager()
    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private let totalTriviaQuestionsAnsweredKey   = "ff.stats.totalTriviaQuestionsAnswered"
    private let totalTriviaCorrectKey             = "ff.stats.totalTriviaCorrect"
    private let dailyTriviaSessionsCompletedKey   = "ff.stats.dailyTriviaSessionsCompleted"
    private let endlessTriviaSessionsCompletedKey = "ff.stats.endlessTriviaSessionsCompleted"
    private let favoritesOpenedCountKey           = "ff.stats.favoritesOpenedCount"
    private let appLaunchCountKey                 = "ff.stats.appLaunchCount"
    private let firstLaunchDateKey                = "ff.stats.firstLaunchDate"
    private let lastLaunchDateKey                 = "ff.stats.lastLaunchDate"
    private let discoverCardsViewedKey            = "ff.stats.discoverCardsViewed"
    private let totalQuotesFavoritedKey           = "ff.stats.totalQuotesFavorited"

    // NEW: Remember which version we already prompted for a rating
    private let lastVersionPromptedForReviewKey   = "ff.lastVersionPromptedForReview"

    private init() {
        ensureFirstLaunchDate()
    }

    // MARK: - One-time setup

    private func ensureFirstLaunchDate() {
        if defaults.object(forKey: firstLaunchDateKey) as? Date == nil {
            let now = Date()
            defaults.set(now, forKey: firstLaunchDateKey)
            defaults.set(now, forKey: lastLaunchDateKey)
        }
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let cal = Calendar.current
        let s = cal.startOfDay(for: start)
        let e = cal.startOfDay(for: end)
        return cal.dateComponents([.day], from: s, to: e).day ?? 0
    }

    // MARK: - Public read-only stats

    var totalTriviaQuestionsAnswered: Int {
        defaults.integer(forKey: totalTriviaQuestionsAnsweredKey)
    }

    /// Alias compatibility property
    var totalTriviaAnswered: Int {
        totalTriviaQuestionsAnswered
    }

    var totalTriviaCorrect: Int {
        defaults.integer(forKey: totalTriviaCorrectKey)
    }

    var triviaAccuracy: Int {
        let total = totalTriviaQuestionsAnswered
        guard total > 0 else { return 0 }
        return Int((Double(totalTriviaCorrect) / Double(total)) * 100)
    }

    var overallAccuracyPercent: Int {
        triviaAccuracy
    }

    var dailyTriviaSessionsCompleted: Int {
        defaults.integer(forKey: dailyTriviaSessionsCompletedKey)
    }

    var endlessTriviaSessionsCompleted: Int {
        defaults.integer(forKey: endlessTriviaSessionsCompletedKey)
    }

    var favoritesOpenedCount: Int {
        defaults.integer(forKey: favoritesOpenedCountKey)
    }

    var appLaunchCount: Int {
        defaults.integer(forKey: appLaunchCountKey)
    }

    var discoverCardsViewed: Int {
        defaults.integer(forKey: discoverCardsViewedKey)
    }

    var totalQuotesFavorited: Int {
        defaults.integer(forKey: totalQuotesFavoritedKey)
    }

    var firstLaunchDate: Date? {
        defaults.object(forKey: firstLaunchDateKey) as? Date
    }

    var lastLaunchDate: Date? {
        defaults.object(forKey: lastLaunchDateKey) as? Date
    }

    /// Rough “unique days used”
    var uniqueDaysUsed: Int {
        guard let first = firstLaunchDate else { return 0 }
        let last = lastLaunchDate ?? Date()
        return daysBetween(first, last) + 1
    }

    // MARK: - Tracking Hooks

    func trackAppLaunched() {
        let newCount = appLaunchCount + 1
        defaults.set(newCount, forKey: appLaunchCountKey)
        defaults.set(Date(), forKey: lastLaunchDateKey)
    }

    func trackTriviaQuestionAnswered(correct: Bool) {
        let newTotal = totalTriviaQuestionsAnswered + 1
        defaults.set(newTotal, forKey: totalTriviaQuestionsAnsweredKey)

        if correct {
            let newCorrect = totalTriviaCorrect + 1
            defaults.set(newCorrect, forKey: totalTriviaCorrectKey)
        }

        // NEW — Check if it's time to ask for an app review
        maybeRequestReviewIfNeeded()
    }

    func trackDailyTriviaSessionCompleted() {
        let newValue = dailyTriviaSessionsCompleted + 1
        defaults.set(newValue, forKey: dailyTriviaSessionsCompletedKey)
    }

    func trackEndlessTriviaSessionCompleted() {
        let newValue = endlessTriviaSessionsCompleted + 1
        defaults.set(newValue, forKey: endlessTriviaSessionsCompletedKey)
    }

    func trackEndlessTriviaAnswer(correct: Bool) {
        trackTriviaQuestionAnswered(correct: correct)
    }

    func trackFavoritesOpened() {
        let newValue = favoritesOpenedCount + 1
        defaults.set(newValue, forKey: favoritesOpenedCountKey)
    }

    func trackDiscoverCardViewed() {
        let newValue = discoverCardsViewed + 1
        defaults.set(newValue, forKey: discoverCardsViewedKey)
    }

    func trackQuoteFavorited() {
        let newValue = totalQuotesFavorited + 1
        defaults.set(newValue, forKey: totalQuotesFavoritedKey)
    }

    // MARK: - Rating Prompt Logic

    private func maybeRequestReviewIfNeeded() {
        // Only consider asking after the user has engaged enough
        let minimumTriviaToAsk = 20
        guard totalTriviaQuestionsAnswered >= minimumTriviaToAsk else { return }

        // Only once per app version
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard !currentVersion.isEmpty else { return }

        let lastVersionPrompted = defaults.string(forKey: lastVersionPromptedForReviewKey)
        guard lastVersionPrompted != currentVersion else {
            return // already asked this version
        }

        #if canImport(UIKit)
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {

            // iOS 18+ uses new API, older OS stays on SKStoreReviewController
            if #available(iOS 18.0, *) {
                AppStore.requestReview(in: scene)
            } else {
                SKStoreReviewController.requestReview(in: scene)
            }

            defaults.set(currentVersion, forKey: lastVersionPromptedForReviewKey)
        }
        #endif
    }
}
