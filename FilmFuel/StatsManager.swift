//
//  StatsManager.swift
//  FilmFuel
//
//  Enhanced with gamification, streaks, XP, achievements, and engagement triggers.
//  Now integrated with AchievementDefinition system for comprehensive achievement tracking.
//

import Foundation
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

final class StatsManager {
    
    static let shared = StatsManager()
    private let defaults = UserDefaults.standard
    
    // MARK: - Notification Names (for UI updates)
    
    static let achievementUnlocked = Notification.Name("ff.achievementUnlocked")
    static let levelUp = Notification.Name("ff.levelUp")
    static let streakMilestone = Notification.Name("ff.streakMilestone")
    static let xpGained = Notification.Name("ff.xpGained")
    
    // MARK: - Keys
    
    private let prefix = "ff.stats."
    
    // Core stats
    private var totalTriviaQuestionsAnsweredKey: String { prefix + "totalTriviaAnswered" }
    private var totalTriviaCorrectKey: String { prefix + "totalTriviaCorrect" }
    private var dailyTriviaSessionsCompletedKey: String { prefix + "dailyTriviaSessionsCompleted" }
    private var endlessTriviaSessionsCompletedKey: String { prefix + "endlessTriviaSessionsCompleted" }
    private var favoritesOpenedCountKey: String { prefix + "favoritesOpenedCount" }
    private var appLaunchCountKey: String { prefix + "appLaunchCount" }
    private var firstLaunchDateKey: String { prefix + "firstLaunchDate" }
    private var lastLaunchDateKey: String { prefix + "lastLaunchDate" }
    private var discoverCardsViewedKey: String { prefix + "discoverCardsViewed" }
    private var totalQuotesFavoritedKey: String { prefix + "totalQuotesFavorited" }
    private var sharesCountKey: String { prefix + "sharesCount" }
    private var watchlistCountKey: String { prefix + "watchlistCount" }
    private var userLevelKey: String { prefix + "userLevel" }
    private var achievementsUnlockedCountKey: String { prefix + "achievementsUnlocked" }
    
    // Gamification
    private var totalXPKey: String { prefix + "totalXP" }
    private var currentStreakKey: String { prefix + "currentStreak" }
    private var longestStreakKey: String { prefix + "longestStreak" }
    private var lastActiveDateKey: String { prefix + "lastActiveDate" }
    private var unlockedAchievementsKey: String { prefix + "unlockedAchievements" }
    private var perfectRoundsKey: String { prefix + "perfectRounds" }
    private var perfectWeeksKey: String { prefix + "perfectWeeks" }
    private var totalMoviesFavoritedKey: String { prefix + "totalMoviesFavorited" }
    private var totalWatchlistAddsKey: String { prefix + "totalWatchlistAdds" }
    private var totalSeenMarkedKey: String { prefix + "totalSeenMarked" }
    private var totalShufflesKey: String { prefix + "totalShuffles" }
    private var totalSmartPicksUsedKey: String { prefix + "totalSmartPicksUsed" }
    private var moodsExploredKey: String { prefix + "moodsExplored" }
    private var genresExploredKey: String { prefix + "genresExplored" }
    private var packsPlayedKey: String { prefix + "packsPlayed" }
    
    // Time-based achievements
    private var nightOwlPlaysKey: String { prefix + "nightOwlPlays" }
    private var earlyBirdPlaysKey: String { prefix + "earlyBirdPlays" }
    private var weekendStreakKey: String { prefix + "weekendStreak" }
    
    // Engagement
    private var sessionCountTodayKey: String { prefix + "sessionCountToday.\(todayKey)" }
    private var lastSessionStartKey: String { prefix + "lastSessionStart" }
    private var totalSessionTimeKey: String { prefix + "totalSessionTime" }
    private var consecutiveDaysKey: String { prefix + "consecutiveDays" }
    
    // Review prompt
    private var lastVersionPromptedForReviewKey: String { prefix + "lastVersionPromptedForReview" }
    private var hasRatedAppKey: String { prefix + "hasRatedApp" }
    
    // Weekly tracking for perfect weeks
    private var weeklyCorrectCountKey: String { prefix + "weeklyCorrectCount" }
    private var weeklyTotalCountKey: String { prefix + "weeklyTotalCount" }
    private var lastWeekNumberKey: String { prefix + "lastWeekNumber" }
    
    private init() {
        ensureFirstLaunchDate()
        checkAndUpdateStreak()
        syncWithUserStreakManager()
    }
    
    // MARK: - Date Helpers
    
    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
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
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private func isYesterday(_ date: Date) -> Bool {
        Calendar.current.isDateInYesterday(date)
    }
    
    private func currentWeekNumber() -> Int {
        Calendar.current.component(.weekOfYear, from: Date())
    }
    
    private func currentHour() -> Int {
        Calendar.current.component(.hour, from: Date())
    }
    
    private func isWeekend() -> Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 || weekday == 7 // Sunday or Saturday
    }
    
    // MARK: - Sync with UserStreakManager
    
    private func syncWithUserStreakManager() {
        // Get streak from UserStreakManager if it exists and is higher
        let userStreak = UserStreakManager.bumpForToday()
        if userStreak.current > currentStreak {
            currentStreak = userStreak.current
        }
        if userStreak.best > longestStreak {
            longestStreak = userStreak.best
        }
    }
    
    // MARK: - Core Stats (Read-Only)
    
    var totalTriviaQuestionsAnswered: Int {
        defaults.integer(forKey: totalTriviaQuestionsAnsweredKey)
    }
    
    var totalTriviaAnswered: Int { totalTriviaQuestionsAnswered }
    
    var totalTriviaCorrect: Int {
        defaults.integer(forKey: totalTriviaCorrectKey)
    }
    
    var triviaAccuracy: Int {
        let total = totalTriviaQuestionsAnswered
        guard total > 0 else { return 0 }
        return Int((Double(totalTriviaCorrect) / Double(total)) * 100)
    }
    
    var overallAccuracyPercent: Int { triviaAccuracy }
    
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
    
    var sharesCount: Int {
        defaults.integer(forKey: sharesCountKey)
    }
    
    var watchlistCount: Int {
        defaults.integer(forKey: watchlistCountKey)
    }
    
    var firstLaunchDate: Date? {
        defaults.object(forKey: firstLaunchDateKey) as? Date
    }
    
    var lastLaunchDate: Date? {
        defaults.object(forKey: lastLaunchDateKey) as? Date
    }
    
    var uniqueDaysUsed: Int {
        guard let first = firstLaunchDate else { return 0 }
        let last = lastLaunchDate ?? Date()
        return daysBetween(first, last) + 1
    }
    
    // MARK: - Gamification Stats
    
    var totalXP: Int {
        get { defaults.integer(forKey: totalXPKey) }
        set { defaults.set(newValue, forKey: totalXPKey) }
    }
    
    var currentStreak: Int {
        get { defaults.integer(forKey: currentStreakKey) }
        set {
            defaults.set(newValue, forKey: currentStreakKey)
            // Also update the daily streak key used by AchievementDefinition
            defaults.set(newValue, forKey: "ff.dailyStreak")
        }
    }
    
    var longestStreak: Int {
        get { defaults.integer(forKey: longestStreakKey) }
        set { defaults.set(newValue, forKey: longestStreakKey) }
    }
    
    var perfectRounds: Int {
        get { defaults.integer(forKey: perfectRoundsKey) }
        set { defaults.set(newValue, forKey: perfectRoundsKey) }
    }
    
    var perfectWeeks: Int {
        get { defaults.integer(forKey: perfectWeeksKey) }
        set {
            defaults.set(newValue, forKey: perfectWeeksKey)
            defaults.set(newValue, forKey: "ff.stats.perfectWeeks")
        }
    }
    
    var totalMoviesFavorited: Int {
        get { defaults.integer(forKey: totalMoviesFavoritedKey) }
        set { defaults.set(newValue, forKey: totalMoviesFavoritedKey) }
    }
    
    var totalWatchlistAdds: Int {
        get { defaults.integer(forKey: totalWatchlistAddsKey) }
        set {
            defaults.set(newValue, forKey: totalWatchlistAddsKey)
            defaults.set(newValue, forKey: "ff.stats.watchlistCount")
        }
    }
    
    var totalSeenMarked: Int {
        get { defaults.integer(forKey: totalSeenMarkedKey) }
        set { defaults.set(newValue, forKey: totalSeenMarkedKey) }
    }
    
    var totalShuffles: Int {
        get { defaults.integer(forKey: totalShufflesKey) }
        set { defaults.set(newValue, forKey: totalShufflesKey) }
    }
    
    var totalSmartPicksUsed: Int {
        get { defaults.integer(forKey: totalSmartPicksUsedKey) }
        set { defaults.set(newValue, forKey: totalSmartPicksUsedKey) }
    }
    
    var nightOwlPlays: Int {
        get { defaults.integer(forKey: nightOwlPlaysKey) }
        set {
            defaults.set(newValue, forKey: nightOwlPlaysKey)
            defaults.set(newValue, forKey: "ff.stats.nightOwlPlays")
        }
    }
    
    var earlyBirdPlays: Int {
        get { defaults.integer(forKey: earlyBirdPlaysKey) }
        set {
            defaults.set(newValue, forKey: earlyBirdPlaysKey)
            defaults.set(newValue, forKey: "ff.stats.earlyBirdPlays")
        }
    }
    
    var weekendStreak: Int {
        get { defaults.integer(forKey: weekendStreakKey) }
        set {
            defaults.set(newValue, forKey: weekendStreakKey)
            defaults.set(newValue, forKey: "ff.stats.weekendStreak")
        }
    }
    
    var packsPlayed: Set<String> {
        get {
            let array = defaults.stringArray(forKey: packsPlayedKey) ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: packsPlayedKey)
            defaults.set(newValue.count, forKey: "ff.stats.packsPlayed")
        }
    }
    
    var unlockedAchievements: Set<String> {
        get {
            let array = defaults.stringArray(forKey: unlockedAchievementsKey) ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: unlockedAchievementsKey)
        }
    }
    
    var moodsExplored: Set<String> {
        get {
            let array = defaults.stringArray(forKey: moodsExploredKey) ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: moodsExploredKey)
        }
    }
    
    var genresExplored: Set<Int> {
        get {
            let array = defaults.array(forKey: genresExploredKey) as? [Int] ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: genresExploredKey)
            defaults.set(newValue.count, forKey: "ff.stats.genresExplored")
        }
    }
    
    // MARK: - User Level
    
    var userLevel: Int {
        // Calculate level based on XP thresholds
        let xp = totalXP
        let level: Int
        if xp >= 5000 { level = 10 }      // Legend
        else if xp >= 3500 { level = 9 }  // Master
        else if xp >= 2500 { level = 8 }  // Expert
        else if xp >= 1800 { level = 7 }  // Advanced
        else if xp >= 1200 { level = 6 }  // Elite
        else if xp >= 800 { level = 5 }   // Connoisseur
        else if xp >= 500 { level = 4 }   // Cinephile
        else if xp >= 300 { level = 3 }   // Enthusiast
        else if xp >= 150 { level = 2 }   // Explorer
        else if xp >= 50 { level = 1 }    // Beginner
        else { level = 0 }                 // Newbie
        
        // Update the stored level for achievement tracking
        defaults.set(level, forKey: "ff.stats.userLevel")
        return level
    }
    
    var userLevelTitle: String {
        switch userLevel {
        case 0: return "Film Newbie"
        case 1: return "Beginner"
        case 2: return "Explorer"
        case 3: return "Enthusiast"
        case 4: return "Cinephile"
        case 5: return "Connoisseur"
        case 6: return "Elite Curator"
        case 7: return "Advanced Critic"
        case 8: return "Expert"
        case 9: return "Master"
        case 10: return "FilmFuel Legend"
        default: return "Film Newbie"
        }
    }
    
    var xpToNextLevel: Int {
        let thresholds = [50, 150, 300, 500, 800, 1200, 1800, 2500, 3500, 5000]
        let currentLevel = userLevel
        guard currentLevel < thresholds.count else { return 0 }
        return thresholds[currentLevel] - totalXP
    }
    
    var xpProgressToNextLevel: Double {
        let thresholds = [0, 50, 150, 300, 500, 800, 1200, 1800, 2500, 3500, 5000]
        let currentLevel = userLevel
        guard currentLevel < thresholds.count - 1 else { return 1.0 }
        
        let currentThreshold = thresholds[currentLevel]
        let nextThreshold = thresholds[currentLevel + 1]
        let xpInLevel = totalXP - currentThreshold
        let xpNeeded = nextThreshold - currentThreshold
        
        return Double(xpInLevel) / Double(xpNeeded)
    }
    
    // MARK: - Streak Management
    
    private func checkAndUpdateStreak() {
        guard let lastActive = defaults.object(forKey: lastActiveDateKey) as? Date else {
            // First time - start streak
            currentStreak = 1
            defaults.set(Date(), forKey: lastActiveDateKey)
            return
        }
        
        if isToday(lastActive) {
            // Already active today, streak continues
            return
        } else if isYesterday(lastActive) {
            // Yesterday - extend streak!
            currentStreak += 1
            defaults.set(Date(), forKey: lastActiveDateKey)
            
            if currentStreak > longestStreak {
                longestStreak = currentStreak
            }
            
            // Check streak milestones
            checkStreakMilestones()
        } else {
            // Streak broken
            currentStreak = 1
            defaults.set(Date(), forKey: lastActiveDateKey)
        }
        
        // Also update best correct streak key for achievement tracking
        let bestCorrect = defaults.integer(forKey: "ff.bestCorrectStreak")
        if currentStreak > bestCorrect {
            defaults.set(currentStreak, forKey: "ff.bestCorrectStreak")
        }
    }
    
    private func checkStreakMilestones() {
        let milestones = [3, 7, 14, 30, 60, 100]
        
        if milestones.contains(currentStreak) {
            // Award bonus XP for streak milestones
            let bonusXP = currentStreak * 5
            addXP(bonusXP, reason: "\(currentStreak)-day streak bonus")
            
            NotificationCenter.default.post(
                name: Self.streakMilestone,
                object: nil,
                userInfo: ["streak": currentStreak, "bonusXP": bonusXP]
            )
            
            // Check achievements for this streak
            checkAchievementsForStreak(currentStreak)
        }
    }
    
    private func checkAchievementsForStreak(_ streak: Int) {
        let streakAchievements: [Int: String] = [
            3: "streak_3",
            7: "streak_7",
            14: "streak_14",
            30: "streak_30",
            100: "streak_100"
        ]
        
        for (threshold, achievementId) in streakAchievements {
            if streak >= threshold {
                AchievementDefinition.unlock(achievementId)
            }
        }
    }
    
    // MARK: - XP System
    
    @discardableResult
    func addXP(_ amount: Int, reason: String = "") -> Int {
        let oldLevel = userLevel
        totalXP += amount
        let newLevel = userLevel
        
        // Post XP gained notification
        NotificationCenter.default.post(
            name: Self.xpGained,
            object: nil,
            userInfo: ["amount": amount, "reason": reason, "total": totalXP]
        )
        
        // Check for level up
        if newLevel > oldLevel {
            NotificationCenter.default.post(
                name: Self.levelUp,
                object: nil,
                userInfo: ["oldLevel": oldLevel, "newLevel": newLevel]
            )
            
            // Check level achievements
            if newLevel >= 10 {
                AchievementDefinition.unlock("legend")
            }
        }
        
        return totalXP
    }
    
    // MARK: - Achievement System (Integration with AchievementDefinition)
    
    /// Check and unlock achievements based on current stats
    func checkAllAchievements() {
        // Trivia achievements
        checkTriviaAchievements()
        
        // Streak achievements
        checkStreakAchievements()
        
        // Discovery achievements
        checkDiscoveryAchievements()
        
        // Dedication achievements
        checkDedicationAchievements()
        
        // Social achievements
        checkSocialAchievements()
        
        // Elite achievements
        checkEliteAchievements()
    }
    
    private func checkTriviaAchievements() {
        let answered = totalTriviaQuestionsAnswered
        let correct = totalTriviaCorrect
        let accuracy = triviaAccuracy
        let bestEndless = defaults.integer(forKey: "ff.bestEndlessRound")
        
        // Questions answered
        if answered >= 1 { AchievementDefinition.unlock("trivia_first") }
        if answered >= 10 { AchievementDefinition.unlock("trivia_10") }
        if answered >= 50 { AchievementDefinition.unlock("trivia_50") }
        if answered >= 100 { AchievementDefinition.unlock("trivia_100") }
        if answered >= 500 { AchievementDefinition.unlock("trivia_500") }
        
        // Accuracy (with minimum questions)
        if answered >= 20 && accuracy >= 80 { AchievementDefinition.unlock("trivia_accuracy_80") }
        if answered >= 50 && accuracy >= 95 { AchievementDefinition.unlock("trivia_accuracy_95") }
        
        // Endless mode
        if bestEndless >= 10 { AchievementDefinition.unlock("endless_10") }
        if bestEndless >= 25 { AchievementDefinition.unlock("endless_25") }
    }
    
    private func checkStreakAchievements() {
        let daily = currentStreak
        let bestCorrect = defaults.integer(forKey: "ff.bestCorrectStreak")
        
        // Daily streaks
        if daily >= 3 { AchievementDefinition.unlock("streak_3") }
        if daily >= 7 { AchievementDefinition.unlock("streak_7") }
        if daily >= 14 { AchievementDefinition.unlock("streak_14") }
        if daily >= 30 { AchievementDefinition.unlock("streak_30") }
        if daily >= 100 { AchievementDefinition.unlock("streak_100") }
        
        // Correct streaks
        if bestCorrect >= 5 { AchievementDefinition.unlock("correct_5") }
        if bestCorrect >= 10 { AchievementDefinition.unlock("correct_10") }
        if bestCorrect >= 25 { AchievementDefinition.unlock("correct_25") }
        if bestCorrect >= 50 { AchievementDefinition.unlock("correct_50") }
    }
    
    private func checkDiscoveryAchievements() {
        let cards = discoverCardsViewed
        let genres = genresExplored.count
        let watchlist = totalWatchlistAdds
        
        // Discovery
        if cards >= 10 { AchievementDefinition.unlock("discover_10") }
        if cards >= 50 { AchievementDefinition.unlock("discover_50") }
        if cards >= 100 { AchievementDefinition.unlock("discover_100") }
        if cards >= 500 { AchievementDefinition.unlock("discover_500") }
        
        // Genres
        if genres >= 5 { AchievementDefinition.unlock("genres_5") }
        
        // Watchlist
        if watchlist >= 10 { AchievementDefinition.unlock("watchlist_10") }
        if watchlist >= 50 { AchievementDefinition.unlock("watchlist_50") }
    }
    
    private func checkDedicationAchievements() {
        let launches = appLaunchCount
        
        // App launches
        if launches >= 10 { AchievementDefinition.unlock("launch_10") }
        if launches >= 50 { AchievementDefinition.unlock("launch_50") }
        if launches >= 100 { AchievementDefinition.unlock("launch_100") }
        if launches >= 365 { AchievementDefinition.unlock("launch_365") }
        
        // Time-based (checked when playing)
        if nightOwlPlays >= 1 { AchievementDefinition.unlock("night_owl") }
        if earlyBirdPlays >= 1 { AchievementDefinition.unlock("early_bird") }
        if weekendStreak >= 10 { AchievementDefinition.unlock("weekend_warrior") }
    }
    
    private func checkSocialAchievements() {
        let shares = sharesCount
        
        if shares >= 1 { AchievementDefinition.unlock("share_first") }
        if shares >= 10 { AchievementDefinition.unlock("share_10") }
        if shares >= 50 { AchievementDefinition.unlock("share_50") }
    }
    
    private func checkEliteAchievements() {
        let isPlus = defaults.bool(forKey: "ff.entitlements.isPlus")
        let achievementsCount = AchievementDefinition.unlockedAchievements().count
        let level = userLevel
        let packs = packsPlayed.count
        
        if isPlus { AchievementDefinition.unlock("plus_member") }
        if perfectWeeks >= 7 { AchievementDefinition.unlock("perfect_week") }
        if achievementsCount >= 20 { AchievementDefinition.unlock("completionist") }
        if level >= 10 { AchievementDefinition.unlock("legend") }
        if packs >= 10 { AchievementDefinition.unlock("all_packs") }
    }
    
    // MARK: - Tracking Hooks
    
    func trackAppLaunched() {
        let newCount = appLaunchCount + 1
        defaults.set(newCount, forKey: appLaunchCountKey)
        defaults.set(Date(), forKey: lastLaunchDateKey)
        
        // Update streak on launch
        checkAndUpdateStreak()
        syncWithUserStreakManager()
        
        // Small XP for returning
        if newCount > 1 {
            addXP(1, reason: "Daily return")
        }
        
        checkAllAchievements()
    }
    
    func trackTriviaQuestionAnswered(correct: Bool) {
        let newTotal = totalTriviaQuestionsAnswered + 1
        defaults.set(newTotal, forKey: totalTriviaQuestionsAnsweredKey)
        
        if correct {
            let newCorrect = totalTriviaCorrect + 1
            defaults.set(newCorrect, forKey: totalTriviaCorrectKey)
            addXP(5, reason: "Correct answer")
        } else {
            addXP(1, reason: "Attempted question")
        }
        
        // Check time-based achievements
        let hour = currentHour()
        if hour >= 0 && hour < 5 {
            nightOwlPlays += 1
        }
        if hour >= 5 && hour < 7 {
            earlyBirdPlays += 1
        }
        
        // Track weekly progress for perfect week
        trackWeeklyProgress(correct: correct)
        
        checkAllAchievements()
        maybeRequestReviewIfNeeded()
    }
    
    private func trackWeeklyProgress(correct: Bool) {
        let currentWeek = currentWeekNumber()
        let lastWeek = defaults.integer(forKey: lastWeekNumberKey)
        
        if currentWeek != lastWeek {
            // New week - check if last week was perfect
            let weeklyCorrect = defaults.integer(forKey: weeklyCorrectCountKey)
            let weeklyTotal = defaults.integer(forKey: weeklyTotalCountKey)
            
            if weeklyTotal >= 7 && weeklyCorrect == weeklyTotal {
                perfectWeeks += 1
            }
            
            // Reset for new week
            defaults.set(0, forKey: weeklyCorrectCountKey)
            defaults.set(0, forKey: weeklyTotalCountKey)
            defaults.set(currentWeek, forKey: lastWeekNumberKey)
        }
        
        // Update weekly counts
        let weeklyTotal = defaults.integer(forKey: weeklyTotalCountKey) + 1
        defaults.set(weeklyTotal, forKey: weeklyTotalCountKey)
        
        if correct {
            let weeklyCorrect = defaults.integer(forKey: weeklyCorrectCountKey) + 1
            defaults.set(weeklyCorrect, forKey: weeklyCorrectCountKey)
        }
    }
    
    func trackDailyTriviaSessionCompleted() {
        let newValue = dailyTriviaSessionsCompleted + 1
        defaults.set(newValue, forKey: dailyTriviaSessionsCompletedKey)
        addXP(10, reason: "Daily trivia completed")
        
        // Track weekend play
        if isWeekend() {
            weekendStreak += 1
        }
        
        checkAllAchievements()
    }
    
    func trackEndlessTriviaSessionCompleted() {
        let newValue = endlessTriviaSessionsCompleted + 1
        defaults.set(newValue, forKey: endlessTriviaSessionsCompletedKey)
        addXP(15, reason: "Endless session completed")
        checkAllAchievements()
    }
    
    func trackPerfectRound() {
        perfectRounds += 1
        addXP(25, reason: "Perfect round!")
        checkAllAchievements()
    }
    
    func trackEndlessTriviaAnswer(correct: Bool) {
        trackTriviaQuestionAnswered(correct: correct)
    }
    
    func trackPackPlayed(_ packId: String) {
        var packs = packsPlayed
        packs.insert(packId)
        packsPlayed = packs
        checkAllAchievements()
    }
    
    func trackFavoritesOpened() {
        let newValue = favoritesOpenedCount + 1
        defaults.set(newValue, forKey: favoritesOpenedCountKey)
    }
    
    func trackDiscoverCardViewed() {
        let newValue = discoverCardsViewed + 1
        defaults.set(newValue, forKey: discoverCardsViewedKey)
        
        // XP every 10 cards viewed
        if newValue % 10 == 0 {
            addXP(2, reason: "Exploring movies")
        }
        
        checkAllAchievements()
    }
    
    func trackQuoteFavorited() {
        let newValue = totalQuotesFavorited + 1
        defaults.set(newValue, forKey: totalQuotesFavoritedKey)
    }
    
    func trackShare() {
        let newValue = sharesCount + 1
        defaults.set(newValue, forKey: sharesCountKey)
        addXP(5, reason: "Shared content")
        checkAllAchievements()
    }
    
    func trackMovieFavorited() {
        totalMoviesFavorited += 1
        addXP(3, reason: "Favorited movie")
        checkAllAchievements()
    }
    
    func trackWatchlistAdd() {
        totalWatchlistAdds += 1
        addXP(2, reason: "Added to watchlist")
        checkAllAchievements()
    }
    
    func trackSeenMarked() {
        totalSeenMarked += 1
        addXP(5, reason: "Marked as seen")
        checkAllAchievements()
    }
    
    func trackShuffle() {
        totalShuffles += 1
        
        // Bonus XP every 5 shuffles
        if totalShuffles % 5 == 0 {
            addXP(3, reason: "Active discovery")
        }
    }
    
    func trackSmartPickUsed() {
        totalSmartPicksUsed += 1
    }
    
    func trackMoodExplored(_ mood: String) {
        var moods = moodsExplored
        moods.insert(mood)
        moodsExplored = moods
        checkAllAchievements()
    }
    
    func trackGenreExplored(_ genreID: Int) {
        var genres = genresExplored
        genres.insert(genreID)
        genresExplored = genres
        checkAllAchievements()
    }
    
    // MARK: - Engagement Metrics
    
    var sessionsToday: Int {
        defaults.integer(forKey: sessionCountTodayKey)
    }
    
    func trackSessionStart() {
        let newCount = sessionsToday + 1
        defaults.set(newCount, forKey: sessionCountTodayKey)
        defaults.set(Date(), forKey: lastSessionStartKey)
    }
    
    var isHighlyEngaged: Bool {
        // User is highly engaged if:
        // - 5+ day streak OR
        // - 50+ trivia correct OR
        // - 100+ cards viewed
        return currentStreak >= 5 || totalTriviaCorrect >= 50 || discoverCardsViewed >= 100
    }
    
    var isNewUser: Bool {
        guard let first = firstLaunchDate else { return true }
        return daysBetween(first, Date()) < 7
    }
    
    var engagementScore: Int {
        // 0-100 score based on activity
        var score = 0
        
        score += min(currentStreak * 5, 25)          // Up to 25 pts for streak
        score += min(totalTriviaCorrect / 5, 25)     // Up to 25 pts for trivia
        score += min(discoverCardsViewed / 20, 25)   // Up to 25 pts for discovery
        score += min(totalMoviesFavorited * 2, 15)   // Up to 15 pts for favorites
        score += min(totalSeenMarked, 10)            // Up to 10 pts for seen movies
        
        return min(score, 100)
    }
    
    // MARK: - Rating Prompt Logic
    
    var hasRatedApp: Bool {
        get { defaults.bool(forKey: hasRatedAppKey) }
        set { defaults.set(newValue, forKey: hasRatedAppKey) }
    }
    
    private func maybeRequestReviewIfNeeded() {
        // Don't ask if already rated
        guard !hasRatedApp else { return }
        
        // Only ask highly engaged users
        guard isHighlyEngaged else { return }
        
        // Minimum engagement threshold
        let minimumTriviaToAsk = 20
        guard totalTriviaQuestionsAnswered >= minimumTriviaToAsk else { return }
        
        // Good accuracy suggests happy user
        guard triviaAccuracy >= 60 else { return }
        
        // Only once per app version
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard !currentVersion.isEmpty else { return }
        
        let lastVersionPrompted = defaults.string(forKey: lastVersionPromptedForReviewKey)
        guard lastVersionPrompted != currentVersion else { return }
        
        #if canImport(UIKit)
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            
            if #available(iOS 18.0, *) {
                AppStore.requestReview(in: scene)
            } else {
                SKStoreReviewController.requestReview(in: scene)
            }
            
            defaults.set(currentVersion, forKey: lastVersionPromptedForReviewKey)
        }
        #endif
    }
    
    // MARK: - Reset (for testing)
    
    func resetAllStats() {
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
    }
}

// MARK: - UserStreakManager (Integrated)

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
