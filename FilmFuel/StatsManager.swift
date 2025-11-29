//
//  StatsManager.swift
//  FilmFuel
//
//  Enhanced with gamification, streaks, XP, achievements, and engagement triggers
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
    private var totalTriviaQuestionsAnsweredKey: String { prefix + "totalTriviaQuestionsAnswered" }
    private var totalTriviaCorrectKey: String { prefix + "totalTriviaCorrect" }
    private var dailyTriviaSessionsCompletedKey: String { prefix + "dailyTriviaSessionsCompleted" }
    private var endlessTriviaSessionsCompletedKey: String { prefix + "endlessTriviaSessionsCompleted" }
    private var favoritesOpenedCountKey: String { prefix + "favoritesOpenedCount" }
    private var appLaunchCountKey: String { prefix + "appLaunchCount" }
    private var firstLaunchDateKey: String { prefix + "firstLaunchDate" }
    private var lastLaunchDateKey: String { prefix + "lastLaunchDate" }
    private var discoverCardsViewedKey: String { prefix + "discoverCardsViewed" }
    private var totalQuotesFavoritedKey: String { prefix + "totalQuotesFavorited" }
    
    // Gamification
    private var totalXPKey: String { prefix + "totalXP" }
    private var currentStreakKey: String { prefix + "currentStreak" }
    private var longestStreakKey: String { prefix + "longestStreak" }
    private var lastActiveDate: String { prefix + "lastActiveDate" }
    private var unlockedAchievementsKey: String { prefix + "unlockedAchievements" }
    private var perfectRoundsKey: String { prefix + "perfectRounds" }
    private var totalMoviesFavoritedKey: String { prefix + "totalMoviesFavorited" }
    private var totalWatchlistAddsKey: String { prefix + "totalWatchlistAdds" }
    private var totalSeenMarkedKey: String { prefix + "totalSeenMarked" }
    private var totalShufflesKey: String { prefix + "totalShuffles" }
    private var totalSmartPicksUsedKey: String { prefix + "totalSmartPicksUsed" }
    private var moodsExploredKey: String { prefix + "moodsExplored" }
    private var genresExploredKey: String { prefix + "genresExplored" }
    
    // Engagement
    private var sessionCountTodayKey: String { prefix + "sessionCountToday.\(todayKey)" }
    private var lastSessionStartKey: String { prefix + "lastSessionStart" }
    private var totalSessionTimeKey: String { prefix + "totalSessionTime" }
    private var consecutiveDaysKey: String { prefix + "consecutiveDays" }
    
    // Review prompt
    private var lastVersionPromptedForReviewKey: String { prefix + "lastVersionPromptedForReview" }
    private var hasRatedAppKey: String { prefix + "hasRatedApp" }
    
    private init() {
        ensureFirstLaunchDate()
        checkAndUpdateStreak()
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
        set { defaults.set(newValue, forKey: currentStreakKey) }
    }
    
    var longestStreak: Int {
        get { defaults.integer(forKey: longestStreakKey) }
        set { defaults.set(newValue, forKey: longestStreakKey) }
    }
    
    var perfectRounds: Int {
        get { defaults.integer(forKey: perfectRoundsKey) }
        set { defaults.set(newValue, forKey: perfectRoundsKey) }
    }
    
    var totalMoviesFavorited: Int {
        get { defaults.integer(forKey: totalMoviesFavoritedKey) }
        set { defaults.set(newValue, forKey: totalMoviesFavoritedKey) }
    }
    
    var totalWatchlistAdds: Int {
        get { defaults.integer(forKey: totalWatchlistAddsKey) }
        set { defaults.set(newValue, forKey: totalWatchlistAddsKey) }
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
        }
    }
    
    // MARK: - User Level
    
    var userLevel: Int {
        // Calculate level based on XP thresholds
        let xp = totalXP
        if xp >= 2500 { return 5 } // Elite
        if xp >= 1000 { return 4 } // Connoisseur
        if xp >= 400 { return 3 }  // Cinephile
        if xp >= 150 { return 2 }  // Enthusiast
        if xp >= 50 { return 1 }   // Explorer
        return 0                    // Newbie
    }
    
    var userLevelTitle: String {
        switch userLevel {
        case 0: return "Film Newbie"
        case 1: return "Explorer"
        case 2: return "Enthusiast"
        case 3: return "Cinephile"
        case 4: return "Connoisseur"
        case 5: return "Elite Curator"
        default: return "Film Newbie"
        }
    }
    
    var xpToNextLevel: Int {
        let thresholds = [50, 150, 400, 1000, 2500]
        let currentLevel = userLevel
        guard currentLevel < thresholds.count else { return 0 }
        return thresholds[currentLevel] - totalXP
    }
    
    // MARK: - Streak Management
    
    private func checkAndUpdateStreak() {
        guard let lastActive = defaults.object(forKey: lastActiveDate) as? Date else {
            // First time - start streak
            currentStreak = 1
            defaults.set(Date(), forKey: lastActiveDate)
            return
        }
        
        if isToday(lastActive) {
            // Already active today, streak continues
            return
        } else if isYesterday(lastActive) {
            // Yesterday - extend streak!
            currentStreak += 1
            defaults.set(Date(), forKey: lastActiveDate)
            
            if currentStreak > longestStreak {
                longestStreak = currentStreak
            }
            
            // Check streak milestones
            checkStreakMilestones()
        } else {
            // Streak broken
            currentStreak = 1
            defaults.set(Date(), forKey: lastActiveDate)
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
        }
        
        return totalXP
    }
    
    // MARK: - Achievement System
    
    func unlockAchievement(_ id: String) {
        guard !unlockedAchievements.contains(id) else { return }
        
        var achievements = unlockedAchievements
        achievements.insert(id)
        unlockedAchievements = achievements
        
        // Get XP reward for this achievement
        let xpReward = achievementXPReward(for: id)
        if xpReward > 0 {
            addXP(xpReward, reason: "Achievement: \(id)")
        }
        
        NotificationCenter.default.post(
            name: Self.achievementUnlocked,
            object: nil,
            userInfo: ["id": id, "xp": xpReward]
        )
    }
    
    func isAchievementUnlocked(_ id: String) -> Bool {
        unlockedAchievements.contains(id)
    }
    
    private func achievementXPReward(for id: String) -> Int {
        // Define XP rewards for each achievement
        let rewards: [String: Int] = [
            "first_trivia": 10,
            "trivia_10": 25,
            "trivia_50": 50,
            "trivia_100": 100,
            "trivia_500": 300,
            "perfect_round": 75,
            "perfect_5": 150,
            "streak_3": 30,
            "streak_7": 75,
            "streak_14": 150,
            "streak_30": 300,
            "streak_100": 1000,
            "first_favorite": 10,
            "favorites_10": 30,
            "favorites_50": 75,
            "first_watchlist": 10,
            "watchlist_25": 50,
            "first_seen": 10,
            "seen_10": 30,
            "seen_50": 100,
            "explorer_100": 40,
            "explorer_500": 150,
            "all_moods": 50,
            "genre_explorer": 40,
            "accuracy_80": 50,
            "accuracy_90": 100,
            "early_adopter": 25,
            "week_warrior": 75,
            "monthly_master": 200,
        ]
        return rewards[id] ?? 25
    }
    
    private func checkAchievements() {
        // Trivia achievements
        if totalTriviaQuestionsAnswered >= 1 { unlockAchievement("first_trivia") }
        if totalTriviaCorrect >= 10 { unlockAchievement("trivia_10") }
        if totalTriviaCorrect >= 50 { unlockAchievement("trivia_50") }
        if totalTriviaCorrect >= 100 { unlockAchievement("trivia_100") }
        if totalTriviaCorrect >= 500 { unlockAchievement("trivia_500") }
        
        // Perfect rounds
        if perfectRounds >= 1 { unlockAchievement("perfect_round") }
        if perfectRounds >= 5 { unlockAchievement("perfect_5") }
        
        // Streak achievements
        if currentStreak >= 3 { unlockAchievement("streak_3") }
        if currentStreak >= 7 { unlockAchievement("streak_7") }
        if currentStreak >= 14 { unlockAchievement("streak_14") }
        if currentStreak >= 30 { unlockAchievement("streak_30") }
        if currentStreak >= 100 { unlockAchievement("streak_100") }
        
        // Favorites
        if totalMoviesFavorited >= 1 { unlockAchievement("first_favorite") }
        if totalMoviesFavorited >= 10 { unlockAchievement("favorites_10") }
        if totalMoviesFavorited >= 50 { unlockAchievement("favorites_50") }
        
        // Watchlist
        if totalWatchlistAdds >= 1 { unlockAchievement("first_watchlist") }
        if totalWatchlistAdds >= 25 { unlockAchievement("watchlist_25") }
        
        // Seen
        if totalSeenMarked >= 1 { unlockAchievement("first_seen") }
        if totalSeenMarked >= 10 { unlockAchievement("seen_10") }
        if totalSeenMarked >= 50 { unlockAchievement("seen_50") }
        
        // Discovery
        if discoverCardsViewed >= 100 { unlockAchievement("explorer_100") }
        if discoverCardsViewed >= 500 { unlockAchievement("explorer_500") }
        
        // Moods explored
        if moodsExplored.count >= 7 { unlockAchievement("all_moods") }
        
        // Accuracy
        if totalTriviaQuestionsAnswered >= 20 {
            if triviaAccuracy >= 80 { unlockAchievement("accuracy_80") }
            if triviaAccuracy >= 90 { unlockAchievement("accuracy_90") }
        }
    }
    
    // MARK: - Tracking Hooks
    
    func trackAppLaunched() {
        let newCount = appLaunchCount + 1
        defaults.set(newCount, forKey: appLaunchCountKey)
        defaults.set(Date(), forKey: lastLaunchDateKey)
        
        // Update streak on launch
        checkAndUpdateStreak()
        
        // Small XP for returning
        if newCount > 1 {
            addXP(1, reason: "Daily return")
        }
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
        
        checkAchievements()
        maybeRequestReviewIfNeeded()
    }
    
    func trackDailyTriviaSessionCompleted() {
        let newValue = dailyTriviaSessionsCompleted + 1
        defaults.set(newValue, forKey: dailyTriviaSessionsCompletedKey)
        addXP(10, reason: "Daily trivia completed")
        checkAchievements()
    }
    
    func trackEndlessTriviaSessionCompleted() {
        let newValue = endlessTriviaSessionsCompleted + 1
        defaults.set(newValue, forKey: endlessTriviaSessionsCompletedKey)
        addXP(15, reason: "Endless session completed")
        checkAchievements()
    }
    
    func trackPerfectRound() {
        perfectRounds += 1
        addXP(25, reason: "Perfect round!")
        checkAchievements()
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
        
        // XP every 10 cards viewed
        if newValue % 10 == 0 {
            addXP(2, reason: "Exploring movies")
        }
        
        checkAchievements()
    }
    
    func trackQuoteFavorited() {
        let newValue = totalQuotesFavorited + 1
        defaults.set(newValue, forKey: totalQuotesFavoritedKey)
    }
    
    func trackMovieFavorited() {
        totalMoviesFavorited += 1
        addXP(3, reason: "Favorited movie")
        checkAchievements()
    }
    
    func trackWatchlistAdd() {
        totalWatchlistAdds += 1
        addXP(2, reason: "Added to watchlist")
        checkAchievements()
    }
    
    func trackSeenMarked() {
        totalSeenMarked += 1
        addXP(5, reason: "Marked as seen")
        checkAchievements()
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
        checkAchievements()
    }
    
    func trackGenreExplored(_ genreID: Int) {
        var genres = genresExplored
        genres.insert(genreID)
        genresExplored = genres
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

// MARK: - Achievement Definitions

struct AchievementDefinition {
    let id: String
    let title: String
    let description: String
    let icon: String
    let xpReward: Int
    let category: AchievementCategory
    
    enum AchievementCategory: String {
        case trivia = "Trivia"
        case discovery = "Discovery"
        case engagement = "Engagement"
        case collection = "Collection"
        case mastery = "Mastery"
    }
    
    static let all: [AchievementDefinition] = [
        // Trivia
        AchievementDefinition(id: "first_trivia", title: "Quiz Starter", description: "Answer your first trivia question", icon: "star.fill", xpReward: 10, category: .trivia),
        AchievementDefinition(id: "trivia_10", title: "Getting Started", description: "Answer 10 questions correctly", icon: "brain.fill", xpReward: 25, category: .trivia),
        AchievementDefinition(id: "trivia_50", title: "Trivia Enthusiast", description: "Answer 50 questions correctly", icon: "brain.fill", xpReward: 50, category: .trivia),
        AchievementDefinition(id: "trivia_100", title: "Trivia Master", description: "Answer 100 questions correctly", icon: "graduationcap.fill", xpReward: 100, category: .trivia),
        AchievementDefinition(id: "trivia_500", title: "Trivia Legend", description: "Answer 500 questions correctly", icon: "trophy.fill", xpReward: 300, category: .trivia),
        AchievementDefinition(id: "perfect_round", title: "Perfect Round", description: "Get all questions right in a session", icon: "crown.fill", xpReward: 75, category: .trivia),
        AchievementDefinition(id: "perfect_5", title: "Perfectionist", description: "Complete 5 perfect rounds", icon: "crown.fill", xpReward: 150, category: .trivia),
        AchievementDefinition(id: "accuracy_80", title: "Sharp Mind", description: "Maintain 80%+ accuracy (20+ questions)", icon: "target", xpReward: 50, category: .mastery),
        AchievementDefinition(id: "accuracy_90", title: "Elite Accuracy", description: "Maintain 90%+ accuracy (20+ questions)", icon: "scope", xpReward: 100, category: .mastery),
        
        // Streaks
        AchievementDefinition(id: "streak_3", title: "Getting Hooked", description: "3-day streak", icon: "flame.fill", xpReward: 30, category: .engagement),
        AchievementDefinition(id: "streak_7", title: "Week Warrior", description: "7-day streak", icon: "flame.fill", xpReward: 75, category: .engagement),
        AchievementDefinition(id: "streak_14", title: "Two Week Triumph", description: "14-day streak", icon: "flame.fill", xpReward: 150, category: .engagement),
        AchievementDefinition(id: "streak_30", title: "Monthly Master", description: "30-day streak", icon: "flame.fill", xpReward: 300, category: .engagement),
        AchievementDefinition(id: "streak_100", title: "Centurion", description: "100-day streak", icon: "bolt.fill", xpReward: 1000, category: .engagement),
        
        // Collection
        AchievementDefinition(id: "first_favorite", title: "First Love", description: "Favorite your first movie", icon: "heart.fill", xpReward: 10, category: .collection),
        AchievementDefinition(id: "favorites_10", title: "Building a List", description: "Favorite 10 movies", icon: "heart.fill", xpReward: 30, category: .collection),
        AchievementDefinition(id: "favorites_50", title: "Curator", description: "Favorite 50 movies", icon: "heart.circle.fill", xpReward: 75, category: .collection),
        AchievementDefinition(id: "first_watchlist", title: "Planning Ahead", description: "Add first movie to watchlist", icon: "bookmark.fill", xpReward: 10, category: .collection),
        AchievementDefinition(id: "watchlist_25", title: "Movie Queue", description: "Add 25 movies to watchlist", icon: "bookmark.fill", xpReward: 50, category: .collection),
        AchievementDefinition(id: "first_seen", title: "Movie Watcher", description: "Mark first movie as seen", icon: "eye.fill", xpReward: 10, category: .collection),
        AchievementDefinition(id: "seen_10", title: "Film Fan", description: "Mark 10 movies as seen", icon: "eye.fill", xpReward: 30, category: .collection),
        AchievementDefinition(id: "seen_50", title: "Avid Viewer", description: "Mark 50 movies as seen", icon: "eye.circle.fill", xpReward: 100, category: .collection),
        
        // Discovery
        AchievementDefinition(id: "explorer_100", title: "Explorer", description: "View 100 movie cards", icon: "binoculars.fill", xpReward: 40, category: .discovery),
        AchievementDefinition(id: "explorer_500", title: "Adventurer", description: "View 500 movie cards", icon: "map.fill", xpReward: 150, category: .discovery),
        AchievementDefinition(id: "all_moods", title: "Mood Explorer", description: "Try all mood filters", icon: "theatermasks.fill", xpReward: 50, category: .discovery),
    ]
    
    static func definition(for id: String) -> AchievementDefinition? {
        all.first { $0.id == id }
    }
}
