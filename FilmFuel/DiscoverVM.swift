//
//  DiscoverVM.swift
//  FilmFuel
//
//  Redesigned for maximum retention & monetization
//  Key patterns: Variable rewards, streaks, progression, social proof, loss aversion
//

import Foundation
import SwiftUI
import Combine

// MARK: - Persistence Stores

private enum FavoriteStore {
    private static let key = "ff.discover.favorites.tmdb"
    static func load() -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
    }
    static func save(_ set: Set<Int>) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

private enum RandomSeenStore {
    private static let key = "ff.discover.randomSeen.tmdb"
    static func load() -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
    }
    static func save(_ set: Set<Int>) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

private enum SeenStore {
    private static let key = "ff.discover.seen.tmdb"
    static func load() -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
    }
    static func save(_ set: Set<Int>) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

private enum WatchlistStore {
    private static let key = "ff.discover.watchlist.tmdb"
    static func load() -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
    }
    static func save(_ set: Set<Int>) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

private enum DislikedStore {
    private static let key = "ff.discover.disliked.tmdb"
    static func load() -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
    }
    static func save(_ set: Set<Int>) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

// MARK: - Engagement Metrics Store

private enum EngagementStore {
    private static let prefix = "ff.engagement."
    
    static var totalSessions: Int {
        get { UserDefaults.standard.integer(forKey: prefix + "sessions") }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "sessions") }
    }
    
    static var currentStreak: Int {
        get { UserDefaults.standard.integer(forKey: prefix + "streak") }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "streak") }
    }
    
    static var longestStreak: Int {
        get { UserDefaults.standard.integer(forKey: prefix + "longestStreak") }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "longestStreak") }
    }
    
    static var lastSessionDate: Date? {
        get { UserDefaults.standard.object(forKey: prefix + "lastSession") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "lastSession") }
    }
    
    static var totalMoviesExplored: Int {
        get { UserDefaults.standard.integer(forKey: prefix + "explored") }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "explored") }
    }
    
    static var perfectMatchesFound: Int {
        get { UserDefaults.standard.integer(forKey: prefix + "perfectMatches") }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "perfectMatches") }
    }
    
    static var weeklyGoalProgress: Int {
        get { UserDefaults.standard.integer(forKey: prefix + "weeklyProgress") }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "weeklyProgress") }
    }
    
    static var freeRewardsEarned: Int {
        get { UserDefaults.standard.integer(forKey: prefix + "freeRewards") }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "freeRewards") }
    }
    
    static var lastRewardClaimDate: Date? {
        get { UserDefaults.standard.object(forKey: prefix + "lastReward") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: prefix + "lastReward") }
    }
}

// MARK: - Movie Mood

enum MovieMood: String, CaseIterable, Identifiable {
    case any, cozy, adrenaline, dateNight, nostalgic, feelGood, mindBend, spooky
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .any:        return "Any Mood"
        case .cozy:       return "Cozy"
        case .adrenaline: return "Adrenaline"
        case .dateNight:  return "Date Night"
        case .nostalgic:  return "Nostalgic"
        case .feelGood:   return "Feel-Good"
        case .mindBend:   return "Mind-Bend"
        case .spooky:     return "Spooky"
        }
    }
    
    var emoji: String {
        switch self {
        case .any:        return "🎬"
        case .cozy:       return "🛋️"
        case .adrenaline: return "⚡"
        case .dateNight:  return "💕"
        case .nostalgic:  return "📼"
        case .feelGood:   return "☀️"
        case .mindBend:   return "🧠"
        case .spooky:     return "👻"
        }
    }
    
    func matches(movie: TMDBMovie) -> Bool {
        if self == .any { return true }
        
        var year: Int? = nil
        if let release = movie.releaseDate, let y = Int(release.prefix(4)) {
            year = y
        }
        
        let ids = Set(movie.genreIDs ?? [])
        func has(_ g: Int) -> Bool { ids.contains(g) }
        
        switch self {
        case .cozy:       return has(10751) || has(16) || has(35) || has(10749)
        case .adrenaline: return has(28) || has(12) || has(53)
        case .dateNight:  return has(10749) || has(35)
        case .nostalgic:  return year.map { $0 < 2008 } ?? false
        case .feelGood:   return has(35) || has(10751) || has(14)
        case .mindBend:   return has(878) || has(9648)
        case .spooky:     return has(27)
        case .any:        return true
        }
    }
}

// MARK: - Taste Profile

struct TasteProfile {
    private(set) var genreCounts: [Int: Int] = [:]
    private(set) var decadeCounts: [Int: Int] = [:]
    private(set) var moodAffinities: [MovieMood: Int] = [:]
    
    var tasteStrength: Double {
        let total = genreCounts.values.reduce(0, +)
        return min(1.0, Double(total) / 50.0)
    }
    
    mutating func record(genreIDs: [Int]) {
        for g in genreIDs {
            genreCounts[g, default: 0] += 1
        }
    }
    
    mutating func recordMood(_ mood: MovieMood) {
        guard mood != .any else { return }
        moodAffinities[mood, default: 0] += 1
    }
    
    mutating func recordDecade(from movie: TMDBMovie, multiplier: Int = 1) {
        guard let dateString = movie.releaseDate,
              let year = Int(dateString.prefix(4)),
              year > 1900 else { return }
        
        let decade = (year / 10) * 10
        guard decade > 1900 else { return }
        
        for _ in 0..<multiplier {
            decadeCounts[decade, default: 0] += 1
        }
    }
    
    var topGenreIDs: [Int] {
        Array(genreCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key })
    }
    
    var favoriteDecade: Int? {
        decadeCounts.max(by: { $0.value < $1.value })?.key
    }
    
    var favoriteMood: MovieMood? {
        moodAffinities.max(by: { $0.value < $1.value })?.key
    }
    
    func score(for movie: TMDBMovie) -> Int {
        let favs = Set(topGenreIDs)
        let movieGenres = Set(movie.genreIDs ?? [])
        return favs.intersection(movieGenres).count
    }
    
    /// Match percentage for social proof / excitement
    func matchPercentage(for movie: TMDBMovie) -> Int {
        guard !topGenreIDs.isEmpty else { return Int.random(in: 72...89) }
        
        let movieGenres = Set(movie.genreIDs ?? [])
        let overlap = Set(topGenreIDs).intersection(movieGenres).count
        let base = 65 + (overlap * 12)
        let bonus = movie.voteAverage >= 7.5 ? 8 : 0
        return min(99, base + bonus + Int.random(in: 0...5))
    }
}

// MARK: - User Level & Progression

enum UserLevel: Int, CaseIterable {
    case newbie = 0
    case explorer = 1
    case enthusiast = 2
    case cinephile = 3
    case connoisseur = 4
    case elite = 5
    
    var title: String {
        switch self {
        case .newbie:      return "Film Newbie"
        case .explorer:    return "Explorer"
        case .enthusiast:  return "Enthusiast"
        case .cinephile:   return "Cinephile"
        case .connoisseur: return "Connoisseur"
        case .elite:       return "Elite Curator"
        }
    }
    
    var icon: String {
        switch self {
        case .newbie:      return "person.fill"
        case .explorer:    return "binoculars.fill"
        case .enthusiast:  return "star.fill"
        case .cinephile:   return "film.fill"
        case .connoisseur: return "crown.fill"
        case .elite:       return "sparkles"
        }
    }
    
    var requiredXP: Int {
        switch self {
        case .newbie:      return 0
        case .explorer:    return 50
        case .enthusiast:  return 150
        case .cinephile:   return 400
        case .connoisseur: return 1000
        case .elite:       return 2500
        }
    }
    
    var perks: [String] {
        switch self {
        case .newbie:
            return ["Basic discovery", "2 smart picks/day"]
        case .explorer:
            return ["Mood filters", "3 smart picks/day"]
        case .enthusiast:
            return ["Taste insights", "4 smart picks/day", "Early access previews"]
        case .cinephile:
            return ["Advanced filters", "6 smart picks/day", "Hidden gems unlock"]
        case .connoisseur:
            return ["Curator collections", "10 smart picks/day", "Priority recommendations"]
        case .elite:
            return ["Everything unlimited", "Beta features", "Direct feedback channel"]
        }
    }
    
    static func level(for xp: Int) -> UserLevel {
        for level in Self.allCases.reversed() {
            if xp >= level.requiredXP {
                return level
            }
        }
        return .newbie
    }
    
    var next: UserLevel? {
        UserLevel(rawValue: rawValue + 1)
    }
}

// MARK: - Reward Types

enum RewardType: Equatable {
    case bonusSmartPicks(Int)
    case exclusiveFilter
    case hiddenGem
    case streakBonus(Int)
    case mysteryReward
    
    var title: String {
        switch self {
        case .bonusSmartPicks(let count): return "+\(count) Smart Picks"
        case .exclusiveFilter:            return "Exclusive Filter"
        case .hiddenGem:                  return "Hidden Gem Unlocked"
        case .streakBonus(let days):      return "\(days)-Day Streak Bonus"
        case .mysteryReward:              return "Mystery Reward"
        }
    }
    
    var icon: String {
        switch self {
        case .bonusSmartPicks: return "sparkles"
        case .exclusiveFilter: return "slider.horizontal.3"
        case .hiddenGem:       return "diamond.fill"
        case .streakBonus:     return "flame.fill"
        case .mysteryReward:   return "gift.fill"
        }
    }
}

// MARK: - Monetization Trigger Events

enum MonetizationTrigger: Equatable {
    case softPaywall(reason: String)
    case hardPaywall(feature: String)
    case limitReached(type: String, remaining: Int)
    case streakAtRisk
    case exclusiveContent
    case socialProof(usersCount: Int)
    case timeLimited(hoursRemaining: Int)
    case upgradeNudge(benefit: String)
    
    var urgency: Double {
        switch self {
        case .hardPaywall:                    return 1.0
        case .limitReached(_, let remaining): return remaining <= 1 ? 0.9 : 0.6
        case .streakAtRisk:                   return 0.85
        case .timeLimited(let hours):         return hours <= 6 ? 0.8 : 0.5
        case .exclusiveContent:               return 0.7
        case .socialProof:                    return 0.5
        case .softPaywall:                    return 0.4
        case .upgradeNudge:                   return 0.3
        }
    }
}

// MARK: - Achievement System

struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let xpReward: Int
    var isUnlocked: Bool = false
    var progress: Double = 0
    
    static let all: [Achievement] = [
        Achievement(id: "first_favorite", title: "First Love", description: "Add your first favorite", icon: "heart.fill", xpReward: 10),
        Achievement(id: "watchlist_5", title: "Planning Ahead", description: "Add 5 movies to watchlist", icon: "bookmark.fill", xpReward: 25),
        Achievement(id: "seen_10", title: "Movie Marathon", description: "Mark 10 movies as seen", icon: "eye.fill", xpReward: 50),
        Achievement(id: "streak_3", title: "Getting Hooked", description: "3-day discovery streak", icon: "flame.fill", xpReward: 30),
        Achievement(id: "streak_7", title: "Week Warrior", description: "7-day discovery streak", icon: "flame.fill", xpReward: 75),
        Achievement(id: "streak_30", title: "Monthly Master", description: "30-day streak", icon: "crown.fill", xpReward: 300),
        Achievement(id: "all_moods", title: "Mood Explorer", description: "Try all mood filters", icon: "theatermasks.fill", xpReward: 40),
        Achievement(id: "hidden_gem", title: "Gem Hunter", description: "Discover a hidden gem", icon: "diamond.fill", xpReward: 35),
        Achievement(id: "perfect_match", title: "Soulmate Film", description: "Find a 95%+ match", icon: "sparkles", xpReward: 50),
        Achievement(id: "share_first", title: "Spreading Joy", description: "Share your first movie", icon: "square.and.arrow.up.fill", xpReward: 20),
    ]
}

// MARK: - ViewModel

@MainActor
final class DiscoverVM: ObservableObject {
    
    // MARK: - Mode & Flavor
    
    enum Mode: String, CaseIterable, Identifiable {
        case forYou, trending, popular, hiddenGems
        
        var id: String { rawValue }
        
        var label: String {
            switch self {
            case .forYou:     return "For You"
            case .trending:   return "Trending"
            case .popular:    return "Popular"
            case .hiddenGems: return "Hidden Gems"
            }
        }
        
        var icon: String {
            switch self {
            case .forYou:     return "sparkles"
            case .trending:   return "flame.fill"
            case .popular:    return "star.fill"
            case .hiddenGems: return "diamond.fill"
            }
        }
        
        var isPremium: Bool {
            self == .hiddenGems
        }
    }
    
    enum RandomFlavor: String, CaseIterable, Identifiable {
        case pure, hotRightNow, criticallyAcclaimed, fromYourTaste, surpriseMe
        
        var id: String { rawValue }
        
        var shortLabel: String {
            switch self {
            case .pure:                return "Pure Random"
            case .hotRightNow:         return "Hot Right Now"
            case .criticallyAcclaimed: return "Critics' Choice"
            case .fromYourTaste:       return "Your Taste"
            case .surpriseMe:          return "Surprise Me"
            }
        }
        
        var isPremium: Bool {
            switch self {
            case .fromYourTaste, .surpriseMe: return true
            default: return false
            }
        }
    }
    
    // MARK: - Genre Mapping
    
    static let genreNameByID: [Int: String] = [
        28: "Action", 12: "Adventure", 16: "Animation", 35: "Comedy",
        80: "Crime", 99: "Documentary", 18: "Drama", 10751: "Family",
        14: "Fantasy", 27: "Horror", 10402: "Music", 9648: "Mystery",
        10749: "Romance", 878: "Sci-Fi", 10770: "TV Movie", 53: "Thriller",
        10752: "War", 37: "Western"
    ]
    
    // MARK: - Published State
    
    @Published private(set) var movies: [TMDBMovie] = []
    @Published var filters: DiscoverFilters = .default
    @Published var selectedMood: MovieMood = .any
    @Published var useSmartMode: Bool = true
    @Published var tasteProfile = TasteProfile()
    @Published var randomFlavor: RandomFlavor = .pure
    
    // Engagement & Progression
    @Published var currentStreak: Int = 0
    @Published var userXP: Int = 0
    @Published var userLevel: UserLevel = .newbie
    @Published var achievements: [Achievement] = Achievement.all
    @Published var weeklyGoal: Int = 7
    @Published var weeklyProgress: Int = 0
    
    // Rewards & Notifications
    @Published var pendingReward: RewardType?
    @Published var showRewardAnimation: Bool = false
    @Published var showStreakAtRisk: Bool = false
    @Published var showLevelUp: Bool = false
    @Published var newLevelReached: UserLevel?
    
    // Monetization
    @Published var showPaywall: Bool = false
    @Published var paywallTrigger: MonetizationTrigger?
    @Published var smartPicksUsedToday: Int = 0
    @Published var bonusSmartPicks: Int = 0
    
    // Social Proof
    @Published var activeUsersNow: Int = 0
    @Published var moviesDiscoveredToday: Int = 0
    
    // Tip nudges
    @Published var showTipNudge: Bool = false
    @Published var tipNudgeMessage: String?
    
    // User preferences
    @Published var favorites: Set<Int> = FavoriteStore.load() {
        didSet { FavoriteStore.save(favorites) }
    }
    @Published var seenMovieIDs: Set<Int> = SeenStore.load() {
        didSet { SeenStore.save(seenMovieIDs) }
    }
    @Published var watchlistMovieIDs: Set<Int> = WatchlistStore.load() {
        didSet { WatchlistStore.save(watchlistMovieIDs) }
    }
    @Published var dislikedMovieIDs: Set<Int> = DislikedStore.load() {
        didSet { DislikedStore.save(dislikedMovieIDs) }
    }
    
    @Published var mode: Mode = .forYou {
        didSet { Task { await reloadForMode() } }
    }
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchQuery: String = "" {
        didSet { Task { await handleSearchChange() } }
    }
    
    // MARK: - Computed Properties
    
    var displayedMovies: [TMDBMovie] {
        var result = movies
        
        if filters.onlyFavorites {
            result = result.filter { favorites.contains($0.id) }
        }
        
        if filters.minRating > 0 {
            result = result.filter { $0.voteAverage >= filters.minRating }
        }
        
        if filters.minYear != nil || filters.maxYear != nil {
            result = result.filter { movie in
                guard let dateString = movie.releaseDate,
                      let year = Int(dateString.prefix(4)) else { return false }
                if let minY = filters.minYear, year < minY { return false }
                if let maxY = filters.maxYear, year > maxY { return false }
                return true
            }
        }
        
        if !filters.selectedGenreIDs.isEmpty {
            result = result.filter { movie in
                guard let ids = movie.genreIDs, !ids.isEmpty else { return false }
                return !filters.selectedGenreIDs.isDisjoint(with: Set(ids))
            }
        }
        
        if selectedMood != .any {
            result = result.filter { selectedMood.matches(movie: $0) }
        }
        
        if !dislikedMovieIDs.isEmpty {
            result = result.filter { !dislikedMovieIDs.contains($0.id) }
        }
        
        if useSmartMode, !tasteProfile.topGenreIDs.isEmpty, mode == .forYou, !isSearching {
            result = result.sorted { tasteProfile.score(for: $0) > tasteProfile.score(for: $1) }
        }
        
        if mode == .forYou, !isSearching {
            result = result.filter { !seenMovieIDs.contains($0.id) }
        }
        
        return result
    }
    
    var topGenreNames: [String] {
        tasteProfile.topGenreIDs.compactMap { Self.genreNameByID[$0] }
    }
    
    var favoriteDecadeLabel: String? {
        guard let decade = tasteProfile.favoriteDecade else { return nil }
        return decade >= 2000 ? "\(decade)s" : "\(decade % 100)s"
    }
    
    var smartPicksRemaining: Int {
        let base = userLevel.rawValue + 2
        let used = smartPicksUsedToday
        return max(0, base + bonusSmartPicks - used)
    }
    
    var xpToNextLevel: Int {
        guard let next = userLevel.next else { return 0 }
        return next.requiredXP - userXP
    }
    
    var levelProgress: Double {
        guard let next = userLevel.next else { return 1.0 }
        let current = userLevel.requiredXP
        let needed = next.requiredXP - current
        let progress = userXP - current
        return Double(progress) / Double(needed)
    }
    
    // MARK: - Private State
    
    private let client: TMDBClientProtocol
    fileprivate var isSearching: Bool = false
    private let randomPagesToLoad = 5
    private let maxRandomMovies = 40
    private var sessionSeenRandomMovieIDs: Set<Int> = []
    private var lifetimeSeenRandomMovieIDs: Set<Int> = RandomSeenStore.load()
    private let maxLifetimeSeenCount = 600
    private let randomBaseSeed: Int
    private var randomReloadCount: Int = 0
    private var shuffleCount: Int = 0
    private var detailOpenCount: Int = 0
    private var sessionStartTime: Date = Date()
    private var moodsTriedThisSession: Set<MovieMood> = []
    
    // MARK: - Init
    
    init(client: TMDBClientProtocol) {
        self.client = client
        self.randomBaseSeed = Int.random(in: 0...999_999)
        loadEngagementData()
        generateSocialProof()
    }
    
    // MARK: - Lifecycle
    
    private func loadEngagementData() {
        currentStreak = EngagementStore.currentStreak
        userXP = UserDefaults.standard.integer(forKey: "ff.user.xp")
        userLevel = UserLevel.level(for: userXP)
        weeklyProgress = EngagementStore.weeklyGoalProgress
        smartPicksUsedToday = loadTodaysSmartPickUsage()
        
        checkAndUpdateStreak()
        checkStreakAtRisk()
    }
    
    private func generateSocialProof() {
        // Simulated but believable numbers
        let hour = Calendar.current.component(.hour, from: Date())
        let baseUsers = hour >= 18 && hour <= 23 ? 1200 : 450
        activeUsersNow = baseUsers + Int.random(in: -100...200)
        moviesDiscoveredToday = 8500 + Int.random(in: -500...1500)
    }
    
    private func checkAndUpdateStreak() {
        guard let lastSession = EngagementStore.lastSessionDate else {
            // First session ever
            currentStreak = 1
            EngagementStore.currentStreak = 1
            EngagementStore.lastSessionDate = Date()
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(lastSession) {
            // Same day, streak continues
            return
        } else if calendar.isDateInYesterday(lastSession) {
            // Yesterday - extend streak
            currentStreak += 1
            EngagementStore.currentStreak = currentStreak
            EngagementStore.lastSessionDate = now
            
            if currentStreak > EngagementStore.longestStreak {
                EngagementStore.longestStreak = currentStreak
            }
            
            // Streak milestones
            if [3, 7, 14, 30].contains(currentStreak) {
                triggerStreakReward()
            }
        } else {
            // Streak broken
            currentStreak = 1
            EngagementStore.currentStreak = 1
            EngagementStore.lastSessionDate = now
        }
    }
    
    private func checkStreakAtRisk() {
        guard let lastSession = EngagementStore.lastSessionDate,
              currentStreak >= 3 else { return }
        
        let calendar = Calendar.current
        if calendar.isDateInYesterday(lastSession) {
            // User came back - check if it's getting late
            let hour = calendar.component(.hour, from: Date())
            if hour >= 20 {
                showStreakAtRisk = true
            }
        }
    }
    
    private func triggerStreakReward() {
        let reward: RewardType = .streakBonus(currentStreak)
        pendingReward = reward
        
        // Bonus smart picks for streaks
        if currentStreak >= 7 {
            bonusSmartPicks += 3
        } else if currentStreak >= 3 {
            bonusSmartPicks += 1
        }
        
        addXP(currentStreak * 5)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showRewardAnimation = true
        }
    }
    
    // MARK: - XP & Leveling
    
    func addXP(_ amount: Int) {
        let oldLevel = userLevel
        userXP += amount
        UserDefaults.standard.set(userXP, forKey: "ff.user.xp")
        
        let newLevel = UserLevel.level(for: userXP)
        if newLevel.rawValue > oldLevel.rawValue {
            userLevel = newLevel
            newLevelReached = newLevel
            showLevelUp = true
            
            // Level up rewards
            bonusSmartPicks += 2
        }
    }
    
    // MARK: - Smart Picks Management
    
    private func loadTodaysSmartPickUsage() -> Int {
        let key = "ff.smartPicks.\(todayKey())"
        return UserDefaults.standard.integer(forKey: key)
    }
    
    private func recordSmartPickUsage() {
        smartPicksUsedToday += 1
        let key = "ff.smartPicks.\(todayKey())"
        UserDefaults.standard.set(smartPicksUsedToday, forKey: key)
    }
    
    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    func canUseSmartMode(isPremium: Bool) -> Bool {
        if isPremium { return true }
        return smartPicksRemaining > 0
    }
    
    func consumeSmartPick() -> Bool {
        if smartPicksRemaining > 0 {
            if bonusSmartPicks > 0 {
                bonusSmartPicks -= 1
            } else {
                recordSmartPickUsage()
            }
            return true
        }
        return false
    }
    
    // MARK: - Public API
    
    func loadInitial() {
        Task { await reloadForMode() }
    }
    
    func shuffleRandomFeed() {
        guard mode == .forYou else {
            loadInitial()
            return
        }
        
        shuffleCount += 1
        addXP(2) // Small XP for engagement
        
        Task {
            await reloadForMode()
            maybeShowTipNudge(reason: .shuffle)
            
            // Variable reward - sometimes give bonus
            if shuffleCount % 5 == 0 && Bool.random() {
                pendingReward = .bonusSmartPicks(1)
                bonusSmartPicks += 1
                showRewardAnimation = true
            }
        }
    }
    
    func toggleFavorite(_ movie: TMDBMovie) {
        if favorites.contains(movie.id) {
            favorites.remove(movie.id)
        } else {
            favorites.insert(movie.id)
            if let ids = movie.genreIDs {
                tasteProfile.record(genreIDs: ids)
            }
            tasteProfile.recordDecade(from: movie)
            addXP(3)
            checkAchievement("first_favorite")
        }
    }
    
    func isFavorite(_ movie: TMDBMovie) -> Bool {
        favorites.contains(movie.id)
    }
    
    func toggleWatchlist(_ movie: TMDBMovie) {
        if watchlistMovieIDs.contains(movie.id) {
            watchlistMovieIDs.remove(movie.id)
        } else {
            watchlistMovieIDs.insert(movie.id)
            addXP(2)
            
            if watchlistMovieIDs.count >= 5 {
                checkAchievement("watchlist_5")
            }
        }
    }
    
    func isInWatchlist(_ movie: TMDBMovie) -> Bool {
        watchlistMovieIDs.contains(movie.id)
    }
    
    func toggleSeen(_ movie: TMDBMovie) {
        if seenMovieIDs.contains(movie.id) {
            seenMovieIDs.remove(movie.id)
        } else {
            seenMovieIDs.insert(movie.id)
            if let ids = movie.genreIDs {
                tasteProfile.record(genreIDs: ids)
            }
            tasteProfile.recordDecade(from: movie)
            addXP(5)
            weeklyProgress += 1
            EngagementStore.weeklyGoalProgress = weeklyProgress
            
            if seenMovieIDs.count >= 10 {
                checkAchievement("seen_10")
            }
        }
    }
    
    func isSeen(_ movie: TMDBMovie) -> Bool {
        seenMovieIDs.contains(movie.id)
    }
    
    func toggleDisliked(_ movie: TMDBMovie) {
        if dislikedMovieIDs.contains(movie.id) {
            dislikedMovieIDs.remove(movie.id)
        } else {
            dislikedMovieIDs.insert(movie.id)
            favorites.remove(movie.id)
            watchlistMovieIDs.remove(movie.id)
        }
    }
    
    func isDisliked(_ movie: TMDBMovie) -> Bool {
        dislikedMovieIDs.contains(movie.id)
    }
    
    func userSelectedMode(_ newMode: Mode) {
        if newMode.isPremium {
            paywallTrigger = .hardPaywall(feature: "Hidden Gems")
            showPaywall = true
            return
        }
        mode = newMode
    }
    
    func userSelectedMood(_ mood: MovieMood) {
        selectedMood = mood
        tasteProfile.recordMood(mood)
        moodsTriedThisSession.insert(mood)
        
        if moodsTriedThisSession.count >= MovieMood.allCases.count - 1 {
            checkAchievement("all_moods")
        }
    }
    
    func recordDetailOpen(_ movie: TMDBMovie) {
        detailOpenCount += 1
        EngagementStore.totalMoviesExplored += 1
        
        if let ids = movie.genreIDs {
            tasteProfile.record(genreIDs: ids)
        }
        tasteProfile.recordDecade(from: movie)
        addXP(1)
        
        // Check for perfect match achievement
        let matchPercent = tasteProfile.matchPercentage(for: movie)
        if matchPercent >= 95 {
            EngagementStore.perfectMatchesFound += 1
            checkAchievement("perfect_match")
        }
        
        maybeShowTipNudge(reason: .detail)
    }
    
    func briefReasonFor(_ movie: TMDBMovie) -> String? {
        guard mode == .forYou, useSmartMode else { return nil }
        
        if selectedMood != .any, selectedMood.matches(movie: movie) {
            return "Matches your \(selectedMood.label.lowercased()) mood"
        }
        
        let favGenreIDs = Set(tasteProfile.topGenreIDs)
        if !favGenreIDs.isEmpty, let movieIDs = movie.genreIDs {
            let overlapIDs = favGenreIDs.intersection(movieIDs)
            if let first = overlapIDs.first, let name = Self.genreNameByID[first] {
                return "Because you love \(name.lowercased())"
            }
        }
        
        if movie.voteAverage >= 8.0, movie.voteCount >= 2000 {
            return "Highly rated by \(movie.voteCount.formatted()) viewers"
        }
        
        return nil
    }
    
    func matchBadgeText(for movie: TMDBMovie) -> String? {
        guard mode == .forYou, useSmartMode, !tasteProfile.topGenreIDs.isEmpty else { return nil }
        let percent = tasteProfile.matchPercentage(for: movie)
        return "\(percent)% match"
    }
    
    func trainTaste(on movie: TMDBMovie, isStrong: Bool) {
        guard let ids = movie.genreIDs, !ids.isEmpty else { return }
        
        let multiplier = isStrong ? 4 : 1
        for _ in 0..<multiplier {
            tasteProfile.record(genreIDs: ids)
            tasteProfile.recordDecade(from: movie)
        }
        
        addXP(isStrong ? 10 : 2)
        
        if isStrong {
            useSmartMode = true
            if mode == .forYou && randomFlavor != .fromYourTaste {
                randomFlavor = .fromYourTaste
            }
        }
    }
    
    // MARK: - Achievements
    
    private func checkAchievement(_ id: String) {
        guard let index = achievements.firstIndex(where: { $0.id == id && !$0.isUnlocked }) else { return }
        
        achievements[index].isUnlocked = true
        achievements[index].progress = 1.0
        
        let xp = achievements[index].xpReward
        addXP(xp)
        
        pendingReward = .mysteryReward
        showRewardAnimation = true
    }
    
    // MARK: - Tip Nudges
    
    func dismissTipNudge() {
        showTipNudge = false
    }
    
    func recordTipSuccess() {
        showTipNudge = false
        addXP(50)
    }
    
    private enum NudgeReason {
        case shuffle, detail
    }
    
    private func maybeShowTipNudge(reason: NudgeReason) {
        switch reason {
        case .shuffle where shuffleCount == 8:
            tipNudgeMessage = "Loving the shuffle? 🍿 Tips help keep FilmFuel free!"
            showTipNudge = true
        case .detail where detailOpenCount == 5:
            tipNudgeMessage = "You've explored \(detailOpenCount) movies! Consider a small tip? 🎬"
            showTipNudge = true
        default:
            break
        }
    }
    
    // MARK: - Data Loading
    
    private func reloadForMode() async {
        guard searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = false
        isLoading = true
        errorMessage = nil
        
        do {
            if filters.isActive {
                try await loadFilteredMoviesForCurrentMode()
            } else {
                switch mode {
                case .forYou:     try await loadRandomMovies()
                case .trending:   try await loadTrendingMovies()
                case .popular:    try await loadPopularMovies()
                case .hiddenGems: try await loadHiddenGems()
                }
            }
        } catch {
            errorMessage = "Could not load movies. Please try again."
            print("TMDB error: \(error)")
        }
        
        isLoading = false
    }
    
    private func loadFilteredMoviesForCurrentMode() async throws {
        let sortBy = filters.sort.tmdbSortKey
        
        let providerIDs: [Int]? = filters.selectedStreamingServices.isEmpty
            ? nil
            : filters.selectedStreamingServices.map { $0.providerID }
        
        let preset = filters.runtimePreset
        let runtimeMin: Int? = preset == .any ? nil : filters.customMinRuntime
        let runtimeMax: Int? = preset == .any ? nil : filters.customMaxRuntime
        
        let actorName = filters.actorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let directorName = filters.directorName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var actorID: Int? = nil
        var directorID: Int? = nil
        
        if !actorName.isEmpty {
            actorID = try? await client.searchPersonID(named: actorName, departmentHint: .acting)
        }
        
        if !directorName.isEmpty {
            directorID = try? await client.searchPersonID(named: directorName, departmentHint: .directing)
        }
        
        let params = TMDBDiscoverParams(
            sortBy: sortBy,
            minRating: filters.minRating > 0 ? filters.minRating : nil,
            minYear: filters.minYear,
            maxYear: filters.maxYear,
            genreIDs: filters.selectedGenreIDs.isEmpty ? nil : Array(filters.selectedGenreIDs),
            watchProviderIDs: providerIDs,
            watchRegion: "US",
            minRuntime: runtimeMin,
            maxRuntime: runtimeMax,
            actorPersonID: actorID,
            directorPersonID: directorID
        )
        
        if mode == .forYou {
            randomReloadCount += 1
        }
        
        let response = try await client.fetchFilteredDiscoverMovies(page: 1, params: params)
        
        var withImages = response.results.filter { $0.posterPath != nil && $0.voteCount >= 20 }
        
        if mode == .forYou {
            let currentSeed = randomBaseSeed &+ randomReloadCount
            var shuffleRNG = SeededGenerator(seed: currentSeed &+ 10_000)
            withImages.shuffle(using: &shuffleRNG)
            withImages = Array(withImages.prefix(maxRandomMovies))
        }
        
        movies = withImages
    }
    
    private func loadRandomMovies() async throws {
        randomReloadCount += 1
        let currentSeed = randomBaseSeed &+ randomReloadCount
        
        let firstDiscover = try await client.fetchDiscoverMovies(page: 1, sortBy: "popularity.desc")
        let totalPages = max(1, min(firstDiscover.totalPages, 500))
        var allResults: [TMDBMovie] = firstDiscover.results
        
        var excludedIDs = Set<Int>()
        if let trending = try? await client.fetchTrendingMovies(page: 1) {
            excludedIDs.formUnion(trending.results.map { $0.id })
        }
        if let popular = try? await client.fetchPopularMovies(page: 1) {
            excludedIDs.formUnion(popular.results.map { $0.id })
        }
        
        var pages = Set<Int>([1])
        var pageRNG = SeededGenerator(seed: currentSeed)
        
        while pages.count < randomPagesToLoad && pages.count < totalPages {
            pages.insert(Int.random(in: 1...totalPages, using: &pageRNG))
        }
        
        for page in pages where page != 1 {
            let resp = try await client.fetchDiscoverMovies(page: page, sortBy: "popularity.desc")
            allResults.append(contentsOf: resp.results)
        }
        
        var withImages = allResults.filter {
            $0.posterPath != nil && $0.voteCount >= 20 && !excludedIDs.contains($0.id)
        }
        
        var seenInBatch = Set<Int>()
        withImages.removeAll { movie in
            if seenInBatch.contains(movie.id) { return true }
            seenInBatch.insert(movie.id)
            return false
        }
        
        var unseen = withImages.filter {
            !sessionSeenRandomMovieIDs.contains($0.id) &&
            !lifetimeSeenRandomMovieIDs.contains($0.id)
        }
        
        if unseen.isEmpty {
            sessionSeenRandomMovieIDs = []
            lifetimeSeenRandomMovieIDs = []
            RandomSeenStore.save(lifetimeSeenRandomMovieIDs)
            unseen = withImages
        }
        
        var shuffleRNG = SeededGenerator(seed: currentSeed &+ 10_000)
        var feed = Array(unseen.shuffled(using: &shuffleRNG).prefix(maxRandomMovies))
        
        switch randomFlavor {
        case .pure:
            break
        case .hotRightNow:
            feed = feed.sorted {
                if $0.voteAverage == $1.voteAverage { return $0.voteCount > $1.voteCount }
                return $0.voteAverage > $1.voteAverage
            }
        case .criticallyAcclaimed:
            feed = feed.filter { $0.voteAverage >= 7.7 }
        case .fromYourTaste:
            if !tasteProfile.topGenreIDs.isEmpty {
                feed = feed.sorted {
                    let s0 = tasteProfile.score(for: $0)
                    let s1 = tasteProfile.score(for: $1)
                    if s0 == s1 { return $0.voteAverage > $1.voteAverage }
                    return s0 > s1
                }
            }
        case .surpriseMe:
            feed = feed.filter { $0.voteAverage >= 6.5 && $0.voteCount < 1000 }
            feed.shuffle(using: &shuffleRNG)
        }
        
        sessionSeenRandomMovieIDs.formUnion(feed.map { $0.id })
        lifetimeSeenRandomMovieIDs.formUnion(feed.map { $0.id })
        
        if lifetimeSeenRandomMovieIDs.count > maxLifetimeSeenCount {
            var rng = SeededGenerator(seed: currentSeed &+ 20_000)
            lifetimeSeenRandomMovieIDs = Set(Array(lifetimeSeenRandomMovieIDs).shuffled(using: &rng).prefix(maxLifetimeSeenCount))
        }
        
        RandomSeenStore.save(lifetimeSeenRandomMovieIDs)
        movies = feed
    }
    
    private func loadTrendingMovies() async throws {
        let response = try await client.fetchTrendingMovies(page: 1)
        movies = response.results.filter { $0.posterPath != nil && $0.voteCount >= 20 }
    }
    
    private func loadPopularMovies() async throws {
        let response = try await client.fetchPopularMovies(page: 1)
        movies = response.results.filter { $0.posterPath != nil && $0.voteCount >= 20 }
    }
    
    private func loadHiddenGems() async throws {
        // Premium feature - would need special API call for underrated films
        let response = try await client.fetchDiscoverMovies(page: Int.random(in: 5...20), sortBy: "vote_average.desc")
        movies = response.results.filter {
            $0.posterPath != nil && $0.voteAverage >= 7.0 && $0.voteCount >= 50 && $0.voteCount <= 500
        }
    }
    
    private func handleSearchChange() async {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            isSearching = false
            await reloadForMode()
            return
        }
        
        isSearching = true
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await client.searchMovies(query: trimmed, page: 1)
            movies = response.results.filter { $0.posterPath != nil && $0.voteCount >= 20 }
        } catch {
            errorMessage = "Search failed. Please try again."
        }
        
        isLoading = false
    }
}

// MARK: - Seeded RNG

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed))
        if self.state == 0 { self.state = 0xdead_beef }
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}
