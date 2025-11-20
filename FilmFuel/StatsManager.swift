import Foundation

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

    // MARK: - Public read-only stats (used by SettingsView / StatsView)

    /// Total trivia questions answered (any mode)
    var totalTriviaQuestionsAnswered: Int {
        defaults.integer(forKey: totalTriviaQuestionsAnsweredKey)
    }

    /// Alias so any `totalTriviaAnswered` references compile
    var totalTriviaAnswered: Int {
        totalTriviaQuestionsAnswered
    }

    var totalTriviaCorrect: Int {
        defaults.integer(forKey: totalTriviaCorrectKey)
    }

    /// Main accuracy calculation
    var triviaAccuracy: Int {
        let total = totalTriviaQuestionsAnswered
        guard total > 0 else { return 0 }
        return Int((Double(totalTriviaCorrect) / Double(total)) * 100)
    }

    /// Alias so anything expecting `overallAccuracyPercent` compiles
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

    /// Lifetime count of times the user has favorited a quote
    var totalQuotesFavorited: Int {
        defaults.integer(forKey: totalQuotesFavoritedKey)
    }

    var firstLaunchDate: Date? {
        defaults.object(forKey: firstLaunchDateKey) as? Date
    }

    var lastLaunchDate: Date? {
        defaults.object(forKey: lastLaunchDateKey) as? Date
    }

    /// Rough “unique days used” = days between first + last launch + 1
    var uniqueDaysUsed: Int {
        guard let first = firstLaunchDate else { return 0 }
        let last = lastLaunchDate ?? Date()
        return daysBetween(first, last) + 1
    }

    // MARK: - Tracking hooks (called from other files)

    func trackAppLaunched() {
        let newCount = appLaunchCount + 1
        defaults.set(newCount, forKey: appLaunchCountKey)
        defaults.set(Date(), forKey: lastLaunchDateKey)
    }

    /// Generic trivia answer tracker (any mode)
    func trackTriviaQuestionAnswered(correct: Bool) {
        let newTotal = totalTriviaQuestionsAnswered + 1
        defaults.set(newTotal, forKey: totalTriviaQuestionsAnsweredKey)

        if correct {
            let newCorrect = totalTriviaCorrect + 1
            defaults.set(newCorrect, forKey: totalTriviaCorrectKey)
        }
    }

    /// Specifically record that a **daily** trivia session finished
    func trackDailyTriviaSessionCompleted() {
        let newValue = dailyTriviaSessionsCompleted + 1
        defaults.set(newValue, forKey: dailyTriviaSessionsCompletedKey)
    }

    /// Specifically record that an **endless** trivia session finished
    func trackEndlessTriviaSessionCompleted() {
        let newValue = endlessTriviaSessionsCompleted + 1
        defaults.set(newValue, forKey: endlessTriviaSessionsCompletedKey)
    }

    /// Specifically record each **endless trivia** answer;
    /// this just delegates to the generic trivia tracker.
    func trackEndlessTriviaAnswer(correct: Bool) {
        trackTriviaQuestionAnswered(correct: correct)
    }

    func trackFavoritesOpened() {
        let newValue = favoritesOpenedCount + 1
        defaults.set(newValue, forKey: favoritesOpenedCountKey)
    }

    /// Count how many Discover cards have actually appeared on screen
    func trackDiscoverCardViewed() {
        let newValue = discoverCardsViewed + 1
        defaults.set(newValue, forKey: discoverCardsViewedKey)
    }

    /// Lifetime counter: each time user successfully adds a favorite
    func trackQuoteFavorited() {
        let newValue = totalQuotesFavorited + 1
        defaults.set(newValue, forKey: totalQuotesFavoritedKey)
    }
}
