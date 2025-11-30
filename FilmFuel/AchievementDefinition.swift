//
//  AchievementDefinition.swift
//  FilmFuel
//
//  Comprehensive achievement system with tiered rewards, categories,
//  and progression tracking to drive engagement and retention.
//

import Foundation
import SwiftUI

// MARK: - Achievement Category

enum AchievementCategory: String, CaseIterable, Identifiable {
    case streaks = "Streaks"
    case trivia = "Trivia Master"
    case discovery = "Explorer"
    case dedication = "Dedication"
    case social = "Social"
    case elite = "Elite"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .streaks: return "flame.fill"
        case .trivia: return "brain.head.profile"
        case .discovery: return "sparkles"
        case .dedication: return "calendar.badge.clock"
        case .social: return "person.2.fill"
        case .elite: return "crown.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .streaks: return .orange
        case .trivia: return .purple
        case .discovery: return .cyan
        case .dedication: return .green
        case .social: return .pink
        case .elite: return .yellow
        }
    }
    
    var description: String {
        switch self {
        case .streaks: return "Build and maintain winning streaks"
        case .trivia: return "Prove your movie knowledge"
        case .discovery: return "Explore new films and genres"
        case .dedication: return "Show your commitment"
        case .social: return "Share the movie love"
        case .elite: return "For the true cinephiles"
        }
    }
}

// MARK: - Achievement Rarity

enum AchievementRarity: String, CaseIterable {
    case common = "Common"
    case uncommon = "Uncommon"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"
    
    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
    
    var glowColor: Color {
        switch self {
        case .common: return .clear
        case .uncommon: return .green.opacity(0.3)
        case .rare: return .blue.opacity(0.4)
        case .epic: return .purple.opacity(0.5)
        case .legendary: return .orange.opacity(0.6)
        }
    }
    
    var xpMultiplier: Double {
        switch self {
        case .common: return 1.0
        case .uncommon: return 1.5
        case .rare: return 2.0
        case .epic: return 3.0
        case .legendary: return 5.0
        }
    }
}

// MARK: - Achievement Definition

struct AchievementDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: AchievementCategory
    let rarity: AchievementRarity
    let xpReward: Int
    let requirement: Int // The target number to unlock
    let isPremium: Bool
    let isSecret: Bool // Hidden until unlocked
    
    // Progress tracking key in UserDefaults/StatsManager
    let progressKey: String?
    
    init(
        id: String,
        title: String,
        description: String,
        icon: String,
        category: AchievementCategory,
        rarity: AchievementRarity,
        xpReward: Int,
        requirement: Int = 1,
        isPremium: Bool = false,
        isSecret: Bool = false,
        progressKey: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.category = category
        self.rarity = rarity
        self.xpReward = xpReward
        self.requirement = requirement
        self.isPremium = isPremium
        self.isSecret = isSecret
        self.progressKey = progressKey
    }
    
    // MARK: - All Achievements
    
    static let all: [AchievementDefinition] = [
        // ═══════════════════════════════════════════════════════════════
        // STREAKS CATEGORY
        // ═══════════════════════════════════════════════════════════════
        
        AchievementDefinition(
            id: "streak_3",
            title: "Warming Up",
            description: "Reach a 3-day streak",
            icon: "flame",
            category: .streaks,
            rarity: .common,
            xpReward: 15,
            requirement: 3,
            progressKey: "ff.dailyStreak"
        ),
        
        AchievementDefinition(
            id: "streak_7",
            title: "Week Warrior",
            description: "Maintain a 7-day streak",
            icon: "flame.fill",
            category: .streaks,
            rarity: .uncommon,
            xpReward: 50,
            requirement: 7,
            progressKey: "ff.dailyStreak"
        ),
        
        AchievementDefinition(
            id: "streak_14",
            title: "Fortnight Fanatic",
            description: "Keep a 14-day streak alive",
            icon: "flame.circle.fill",
            category: .streaks,
            rarity: .rare,
            xpReward: 100,
            requirement: 14,
            progressKey: "ff.dailyStreak"
        ),
        
        AchievementDefinition(
            id: "streak_30",
            title: "Monthly Marvel",
            description: "Achieve a 30-day streak",
            icon: "calendar.badge.checkmark",
            category: .streaks,
            rarity: .epic,
            xpReward: 250,
            requirement: 30,
            progressKey: "ff.dailyStreak"
        ),
        
        AchievementDefinition(
            id: "streak_100",
            title: "Century Club",
            description: "Reach an incredible 100-day streak",
            icon: "star.circle.fill",
            category: .streaks,
            rarity: .legendary,
            xpReward: 1000,
            requirement: 100,
            progressKey: "ff.dailyStreak"
        ),
        
        AchievementDefinition(
            id: "correct_5",
            title: "Hot Streak",
            description: "Get 5 correct answers in a row",
            icon: "checkmark.circle.fill",
            category: .streaks,
            rarity: .common,
            xpReward: 20,
            requirement: 5,
            progressKey: "ff.bestCorrectStreak"
        ),
        
        AchievementDefinition(
            id: "correct_10",
            title: "Rising Star",
            description: "Achieve a 10 correct answer streak",
            icon: "star.fill",
            category: .streaks,
            rarity: .uncommon,
            xpReward: 75,
            requirement: 10,
            progressKey: "ff.bestCorrectStreak"
        ),
        
        AchievementDefinition(
            id: "correct_25",
            title: "Trivia Champion",
            description: "Reach 25 correct in a row",
            icon: "trophy.fill",
            category: .streaks,
            rarity: .rare,
            xpReward: 150,
            requirement: 25,
            progressKey: "ff.bestCorrectStreak"
        ),
        
        AchievementDefinition(
            id: "correct_50",
            title: "Unstoppable",
            description: "50 correct answers without a miss",
            icon: "bolt.shield.fill",
            category: .streaks,
            rarity: .epic,
            xpReward: 400,
            requirement: 50,
            isPremium: true,
            progressKey: "ff.bestCorrectStreak"
        ),
        
        // ═══════════════════════════════════════════════════════════════
        // TRIVIA CATEGORY
        // ═══════════════════════════════════════════════════════════════
        
        AchievementDefinition(
            id: "trivia_first",
            title: "First Take",
            description: "Complete your first trivia question",
            icon: "questionmark.circle",
            category: .trivia,
            rarity: .common,
            xpReward: 10,
            requirement: 1,
            progressKey: "ff.stats.totalTriviaAnswered"
        ),
        
        AchievementDefinition(
            id: "trivia_10",
            title: "Getting Started",
            description: "Answer 10 trivia questions",
            icon: "brain",
            category: .trivia,
            rarity: .common,
            xpReward: 25,
            requirement: 10,
            progressKey: "ff.stats.totalTriviaAnswered"
        ),
        
        AchievementDefinition(
            id: "trivia_50",
            title: "Movie Buff",
            description: "Answer 50 trivia questions",
            icon: "brain.head.profile",
            category: .trivia,
            rarity: .uncommon,
            xpReward: 75,
            requirement: 50,
            progressKey: "ff.stats.totalTriviaAnswered"
        ),
        
        AchievementDefinition(
            id: "trivia_100",
            title: "Trivia Expert",
            description: "Complete 100 trivia questions",
            icon: "graduationcap.fill",
            category: .trivia,
            rarity: .rare,
            xpReward: 150,
            requirement: 100,
            progressKey: "ff.stats.totalTriviaAnswered"
        ),
        
        AchievementDefinition(
            id: "trivia_500",
            title: "Walking IMDB",
            description: "Answer an astounding 500 questions",
            icon: "books.vertical.fill",
            category: .trivia,
            rarity: .epic,
            xpReward: 500,
            requirement: 500,
            progressKey: "ff.stats.totalTriviaAnswered"
        ),
        
        AchievementDefinition(
            id: "trivia_accuracy_80",
            title: "Sharp Mind",
            description: "Maintain 80%+ accuracy (min 20 questions)",
            icon: "target",
            category: .trivia,
            rarity: .uncommon,
            xpReward: 60,
            requirement: 80,
            progressKey: "ff.stats.triviaAccuracy"
        ),
        
        AchievementDefinition(
            id: "trivia_accuracy_95",
            title: "Near Perfect",
            description: "Achieve 95%+ accuracy (min 50 questions)",
            icon: "scope",
            category: .trivia,
            rarity: .epic,
            xpReward: 300,
            requirement: 95,
            isPremium: true,
            progressKey: "ff.stats.triviaAccuracy"
        ),
        
        AchievementDefinition(
            id: "endless_10",
            title: "Marathon Runner",
            description: "Complete 10 endless trivia rounds in one session",
            icon: "infinity",
            category: .trivia,
            rarity: .uncommon,
            xpReward: 50,
            requirement: 10,
            progressKey: "ff.bestEndlessRound"
        ),
        
        AchievementDefinition(
            id: "endless_25",
            title: "Endurance King",
            description: "Survive 25 endless trivia rounds",
            icon: "infinity.circle.fill",
            category: .trivia,
            rarity: .rare,
            xpReward: 125,
            requirement: 25,
            progressKey: "ff.bestEndlessRound"
        ),
        
        // ═══════════════════════════════════════════════════════════════
        // DISCOVERY CATEGORY
        // ═══════════════════════════════════════════════════════════════
        
        AchievementDefinition(
            id: "discover_10",
            title: "Curious Mind",
            description: "Discover 10 movies",
            icon: "eye",
            category: .discovery,
            rarity: .common,
            xpReward: 20,
            requirement: 10,
            progressKey: "ff.stats.discoverCardsViewed"
        ),
        
        AchievementDefinition(
            id: "discover_50",
            title: "Film Explorer",
            description: "Explore 50 movies in Discover",
            icon: "binoculars.fill",
            category: .discovery,
            rarity: .uncommon,
            xpReward: 60,
            requirement: 50,
            progressKey: "ff.stats.discoverCardsViewed"
        ),
        
        AchievementDefinition(
            id: "discover_100",
            title: "Cinematic Voyager",
            description: "Browse through 100 movies",
            icon: "globe.americas.fill",
            category: .discovery,
            rarity: .rare,
            xpReward: 125,
            requirement: 100,
            progressKey: "ff.stats.discoverCardsViewed"
        ),
        
        AchievementDefinition(
            id: "discover_500",
            title: "Film Archaeologist",
            description: "Unearth 500 movies",
            icon: "sparkle.magnifyingglass",
            category: .discovery,
            rarity: .epic,
            xpReward: 350,
            requirement: 500,
            progressKey: "ff.stats.discoverCardsViewed"
        ),
        
        AchievementDefinition(
            id: "genres_5",
            title: "Genre Sampler",
            description: "Explore 5 different genres",
            icon: "square.grid.3x3.fill",
            category: .discovery,
            rarity: .uncommon,
            xpReward: 40,
            requirement: 5,
            progressKey: "ff.stats.genresExplored"
        ),
        
        AchievementDefinition(
            id: "watchlist_10",
            title: "Curator",
            description: "Add 10 movies to your watchlist",
            icon: "bookmark.fill",
            category: .discovery,
            rarity: .common,
            xpReward: 25,
            requirement: 10,
            progressKey: "ff.stats.watchlistCount"
        ),
        
        AchievementDefinition(
            id: "watchlist_50",
            title: "Collector",
            description: "Build a watchlist of 50 movies",
            icon: "tray.full.fill",
            category: .discovery,
            rarity: .rare,
            xpReward: 100,
            requirement: 50,
            progressKey: "ff.stats.watchlistCount"
        ),
        
        // ═══════════════════════════════════════════════════════════════
        // DEDICATION CATEGORY
        // ═══════════════════════════════════════════════════════════════
        
        AchievementDefinition(
            id: "launch_10",
            title: "Regular",
            description: "Open FilmFuel 10 times",
            icon: "arrow.clockwise",
            category: .dedication,
            rarity: .common,
            xpReward: 15,
            requirement: 10,
            progressKey: "ff.stats.appLaunchCount"
        ),
        
        AchievementDefinition(
            id: "launch_50",
            title: "Devoted",
            description: "Launch FilmFuel 50 times",
            icon: "repeat",
            category: .dedication,
            rarity: .uncommon,
            xpReward: 50,
            requirement: 50,
            progressKey: "ff.stats.appLaunchCount"
        ),
        
        AchievementDefinition(
            id: "launch_100",
            title: "True Fan",
            description: "Open the app 100 times",
            icon: "heart.fill",
            category: .dedication,
            rarity: .rare,
            xpReward: 100,
            requirement: 100,
            progressKey: "ff.stats.appLaunchCount"
        ),
        
        AchievementDefinition(
            id: "launch_365",
            title: "FilmFuel Addict",
            description: "Launch the app 365 times",
            icon: "heart.circle.fill",
            category: .dedication,
            rarity: .legendary,
            xpReward: 500,
            requirement: 365,
            progressKey: "ff.stats.appLaunchCount"
        ),
        
        AchievementDefinition(
            id: "night_owl",
            title: "Night Owl",
            description: "Play trivia after midnight",
            icon: "moon.stars.fill",
            category: .dedication,
            rarity: .uncommon,
            xpReward: 35,
            requirement: 1,
            isSecret: true,
            progressKey: "ff.stats.nightOwlPlays"
        ),
        
        AchievementDefinition(
            id: "early_bird",
            title: "Early Bird",
            description: "Complete trivia before 7 AM",
            icon: "sunrise.fill",
            category: .dedication,
            rarity: .uncommon,
            xpReward: 35,
            requirement: 1,
            isSecret: true,
            progressKey: "ff.stats.earlyBirdPlays"
        ),
        
        AchievementDefinition(
            id: "weekend_warrior",
            title: "Weekend Warrior",
            description: "Play on 10 consecutive weekends",
            icon: "calendar.badge.plus",
            category: .dedication,
            rarity: .rare,
            xpReward: 100,
            requirement: 10,
            progressKey: "ff.stats.weekendStreak"
        ),
        
        // ═══════════════════════════════════════════════════════════════
        // SOCIAL CATEGORY
        // ═══════════════════════════════════════════════════════════════
        
        AchievementDefinition(
            id: "share_first",
            title: "Sharing is Caring",
            description: "Share your first quote",
            icon: "square.and.arrow.up",
            category: .social,
            rarity: .common,
            xpReward: 15,
            requirement: 1,
            progressKey: "ff.stats.sharesCount"
        ),
        
        AchievementDefinition(
            id: "share_10",
            title: "Quote Ambassador",
            description: "Share 10 quotes with friends",
            icon: "megaphone.fill",
            category: .social,
            rarity: .uncommon,
            xpReward: 50,
            requirement: 10,
            progressKey: "ff.stats.sharesCount"
        ),
        
        AchievementDefinition(
            id: "share_50",
            title: "Social Butterfly",
            description: "Share 50 quotes",
            icon: "person.3.fill",
            category: .social,
            rarity: .rare,
            xpReward: 125,
            requirement: 50,
            progressKey: "ff.stats.sharesCount"
        ),
        
        // ═══════════════════════════════════════════════════════════════
        // ELITE / PREMIUM CATEGORY
        // ═══════════════════════════════════════════════════════════════
        
        AchievementDefinition(
            id: "plus_member",
            title: "FilmFuel+",
            description: "Upgrade to FilmFuel Plus",
            icon: "crown.fill",
            category: .elite,
            rarity: .rare,
            xpReward: 200,
            requirement: 1,
            isPremium: true,
            progressKey: "ff.entitlements.isPlus"
        ),
        
        AchievementDefinition(
            id: "perfect_week",
            title: "Perfect Week",
            description: "Get every daily quiz correct for a full week",
            icon: "sparkles.rectangle.stack.fill",
            category: .elite,
            rarity: .epic,
            xpReward: 300,
            requirement: 7,
            progressKey: "ff.stats.perfectWeeks"
        ),
        
        AchievementDefinition(
            id: "completionist",
            title: "Completionist",
            description: "Unlock 20 achievements",
            icon: "rosette",
            category: .elite,
            rarity: .epic,
            xpReward: 400,
            requirement: 20,
            progressKey: "ff.stats.achievementsUnlocked"
        ),
        
        AchievementDefinition(
            id: "legend",
            title: "FilmFuel Legend",
            description: "Reach Level 10",
            icon: "laurel.leading",
            category: .elite,
            rarity: .legendary,
            xpReward: 1000,
            requirement: 10,
            progressKey: "ff.stats.userLevel"
        ),
        
        AchievementDefinition(
            id: "all_packs",
            title: "Pack Rat",
            description: "Play trivia from all available packs",
            icon: "square.stack.3d.up.fill",
            category: .elite,
            rarity: .rare,
            xpReward: 150,
            requirement: 10,
            isPremium: true,
            progressKey: "ff.stats.packsPlayed"
        )
    ]
    
    // MARK: - Lookup
    
    static func definition(for id: String) -> AchievementDefinition? {
        all.first { $0.id == id }
    }
    
    static func achievements(for category: AchievementCategory) -> [AchievementDefinition] {
        all.filter { $0.category == category }
    }
    
    static func unlockedAchievements() -> [AchievementDefinition] {
        all.filter { isUnlocked($0.id) }
    }
    
    static func lockedAchievements() -> [AchievementDefinition] {
        all.filter { !isUnlocked($0.id) }
    }
    
    // MARK: - Progress & Unlock Status
    
    static func isUnlocked(_ achievementId: String) -> Bool {
        UserDefaults.standard.bool(forKey: "ff.achievement.unlocked.\(achievementId)")
    }
    
    static func unlock(_ achievementId: String) {
        guard !isUnlocked(achievementId) else { return }
        
        UserDefaults.standard.set(true, forKey: "ff.achievement.unlocked.\(achievementId)")
        UserDefaults.standard.set(Date(), forKey: "ff.achievement.unlockedDate.\(achievementId)")
        
        // Increment total achievements count
        let count = UserDefaults.standard.integer(forKey: "ff.stats.achievementsUnlocked") + 1
        UserDefaults.standard.set(count, forKey: "ff.stats.achievementsUnlocked")
        
        // Award XP
        if let def = definition(for: achievementId) {
            StatsManager.shared.addXP(def.xpReward, reason: "Achievement: \(def.title)")
            
            // Post notification
            NotificationCenter.default.post(
                name: StatsManager.achievementUnlocked,
                object: nil,
                userInfo: ["id": achievementId, "xp": def.xpReward]
            )
        }
    }
    
    static func unlockDate(for achievementId: String) -> Date? {
        UserDefaults.standard.object(forKey: "ff.achievement.unlockedDate.\(achievementId)") as? Date
    }
    
    static func progress(for achievement: AchievementDefinition) -> Double {
        guard let key = achievement.progressKey else { return 0 }
        
        let current = UserDefaults.standard.integer(forKey: key)
        let target = achievement.requirement
        
        return min(1.0, Double(current) / Double(target))
    }
    
    static func currentValue(for achievement: AchievementDefinition) -> Int {
        guard let key = achievement.progressKey else { return 0 }
        return UserDefaults.standard.integer(forKey: key)
    }
    
    // MARK: - Stats
    
    static var totalXPFromAchievements: Int {
        unlockedAchievements().reduce(0) { $0 + $1.xpReward }
    }
    
    static var completionPercentage: Double {
        let unlocked = Double(unlockedAchievements().count)
        let total = Double(all.filter { !$0.isSecret || isUnlocked($0.id) }.count)
        return total > 0 ? (unlocked / total) * 100 : 0
    }
}
