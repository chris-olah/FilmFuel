//
//  FilmFuelEntitlements.swift
//  FilmFuel
//
//  Manages user entitlements, free tier limits, and trial state
//  Designed for strategic monetization with engagement hooks
//

import Foundation
import Combine

@MainActor
final class FilmFuelEntitlements: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var isPlus: Bool = false
    @Published private(set) var isInTrial: Bool = false
    @Published private(set) var trialDaysRemaining: Int = 0
    
    // Free tier limits
    @Published private(set) var freeSmartUsesRemainingToday: Int = 2
    @Published private(set) var freeShufflesRemainingToday: Int = 10
    @Published private(set) var freeFilterSavesRemaining: Int = 1
    
    // Engagement metrics for smart upselling
    @Published private(set) var totalSmartPicksUsedAllTime: Int = 0
    @Published private(set) var totalMoviesDiscovered: Int = 0
    @Published private(set) var daysActiveThisMonth: Int = 0
    @Published private(set) var paywallDismissCount: Int = 0
    
    // MARK: - Keys
    
    private let prefix = "ff.entitlements."
    private var isPlusKey: String { prefix + "isPlus" }
    private var trialStartKey: String { prefix + "trialStart" }
    private var smartUsesTodayKey: String { prefix + "smartUsesToday.\(todayKey)" }
    private var shufflesTodayKey: String { prefix + "shufflesToday.\(todayKey)" }
    private var filterSavesKey: String { prefix + "filterSaves" }
    private var totalSmartKey: String { prefix + "totalSmartPicks" }
    private var totalDiscoveredKey: String { prefix + "totalDiscovered" }
    private var daysActiveKey: String { prefix + "daysActive.\(monthKey)" }
    private var paywallDismissKey: String { prefix + "paywallDismiss" }
    private var lastActiveKey: String { prefix + "lastActive" }
    
    // MARK: - Constants
    
    private let freeSmartPicksPerDay = 2
    private let freeShufflesPerDay = 10
    private let freeFilterSaves = 1
    private let trialDurationDays = 3
    
    // Thresholds for upsell triggers
    let heavyUserSmartPickThreshold = 10 // If they've used 10+ smart picks, they're engaged
    let frequentUserDaysThreshold = 5 // If active 5+ days this month, they're frequent
    
    // MARK: - Computed Properties
    
    var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    var monthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
    
    var isHeavyUser: Bool {
        totalSmartPicksUsedAllTime >= heavyUserSmartPickThreshold
    }
    
    var isFrequentUser: Bool {
        daysActiveThisMonth >= frequentUserDaysThreshold
    }
    
    var shouldShowAggressiveUpsell: Bool {
        // Show more aggressive upsell if they're engaged but haven't converted
        isHeavyUser && !isPlus && paywallDismissCount >= 2
    }
    
    var hasExhaustedFreeTier: Bool {
        freeSmartUsesRemainingToday == 0 && totalSmartPicksUsedAllTime > 5
    }
    
    var eligibleForTrial: Bool {
        // Only offer trial if they haven't had one before
        UserDefaults.standard.object(forKey: trialStartKey) == nil && !isPlus
    }
    
    var trialExpired: Bool {
        guard let trialStart = UserDefaults.standard.object(forKey: trialStartKey) as? Date else {
            return false
        }
        let daysSinceStart = Calendar.current.dateComponents([.day], from: trialStart, to: Date()).day ?? 0
        return daysSinceStart >= trialDurationDays
    }
    
    // MARK: - Init
    
    init() {
        loadState()
        checkAndResetDailyLimits()
        recordDailyActivity()
    }
    
    // MARK: - State Management
    
    private func loadState() {
        isPlus = UserDefaults.standard.bool(forKey: isPlusKey)
        
        // Check trial state
        if let trialStart = UserDefaults.standard.object(forKey: trialStartKey) as? Date {
            let daysSinceStart = Calendar.current.dateComponents([.day], from: trialStart, to: Date()).day ?? 0
            if daysSinceStart < trialDurationDays {
                isInTrial = true
                trialDaysRemaining = trialDurationDays - daysSinceStart
            } else {
                isInTrial = false
                trialDaysRemaining = 0
            }
        }
        
        // Load usage metrics
        totalSmartPicksUsedAllTime = UserDefaults.standard.integer(forKey: totalSmartKey)
        totalMoviesDiscovered = UserDefaults.standard.integer(forKey: totalDiscoveredKey)
        daysActiveThisMonth = UserDefaults.standard.integer(forKey: daysActiveKey)
        paywallDismissCount = UserDefaults.standard.integer(forKey: paywallDismissKey)
        freeFilterSavesRemaining = max(0, freeFilterSaves - UserDefaults.standard.integer(forKey: filterSavesKey))
    }
    
    private func checkAndResetDailyLimits() {
        let smartUsesToday = UserDefaults.standard.integer(forKey: smartUsesTodayKey)
        let shufflesToday = UserDefaults.standard.integer(forKey: shufflesTodayKey)
        
        freeSmartUsesRemainingToday = max(0, freeSmartPicksPerDay - smartUsesToday)
        freeShufflesRemainingToday = max(0, freeShufflesPerDay - shufflesToday)
    }
    
    private func recordDailyActivity() {
        let lastActive = UserDefaults.standard.string(forKey: lastActiveKey)
        
        if lastActive != todayKey {
            // New day - increment days active
            daysActiveThisMonth += 1
            UserDefaults.standard.set(daysActiveThisMonth, forKey: daysActiveKey)
            UserDefaults.standard.set(todayKey, forKey: lastActiveKey)
        }
    }
    
    // MARK: - Plus Status
    
    func setPlus(_ value: Bool) {
        isPlus = value
        UserDefaults.standard.set(value, forKey: isPlusKey)
        
        if value {
            // Reset limits when upgrading
            freeSmartUsesRemainingToday = 999
            freeShufflesRemainingToday = 999
        }
    }
    
    // MARK: - Trial
    
    func startTrial() {
        guard eligibleForTrial else { return }
        
        let now = Date()
        UserDefaults.standard.set(now, forKey: trialStartKey)
        isInTrial = true
        trialDaysRemaining = trialDurationDays
        
        // Grant Plus-like access during trial
        freeSmartUsesRemainingToday = 999
        freeShufflesRemainingToday = 999
    }
    
    // MARK: - Consumption
    
    /// Attempts to consume a free smart pick. Returns true if successful.
    func consumeFreeSmartModeUseIfNeeded() -> Bool {
        // Plus users and trial users have unlimited
        if isPlus || isInTrial {
            return true
        }
        
        if freeSmartUsesRemainingToday > 0 {
            freeSmartUsesRemainingToday -= 1
            
            let usedToday = freeSmartPicksPerDay - freeSmartUsesRemainingToday
            UserDefaults.standard.set(usedToday, forKey: smartUsesTodayKey)
            
            // Track all-time usage
            totalSmartPicksUsedAllTime += 1
            UserDefaults.standard.set(totalSmartPicksUsedAllTime, forKey: totalSmartKey)
            
            return true
        }
        
        return false
    }
    
    /// Attempts to consume a free shuffle. Returns true if successful.
    func consumeFreeShuffle() -> Bool {
        if isPlus || isInTrial {
            return true
        }
        
        if freeShufflesRemainingToday > 0 {
            freeShufflesRemainingToday -= 1
            
            let usedToday = freeShufflesPerDay - freeShufflesRemainingToday
            UserDefaults.standard.set(usedToday, forKey: shufflesTodayKey)
            
            return true
        }
        
        return false
    }
    
    /// Attempts to save a filter preset (free users get 1). Returns true if successful.
    func consumeFilterSave() -> Bool {
        if isPlus || isInTrial {
            return true
        }
        
        if freeFilterSavesRemaining > 0 {
            freeFilterSavesRemaining -= 1
            
            let usedTotal = freeFilterSaves - freeFilterSavesRemaining
            UserDefaults.standard.set(usedTotal, forKey: filterSavesKey)
            
            return true
        }
        
        return false
    }
    
    /// Track movie discovery for engagement metrics
    func recordMovieDiscovered() {
        totalMoviesDiscovered += 1
        UserDefaults.standard.set(totalMoviesDiscovered, forKey: totalDiscoveredKey)
    }
    
    /// Track paywall dismissal for upsell optimization
    func recordPaywallDismiss() {
        paywallDismissCount += 1
        UserDefaults.standard.set(paywallDismissCount, forKey: paywallDismissKey)
    }
    
    // MARK: - Bonus Grants
    
    /// Grant bonus smart picks (e.g., from achievements, streaks)
    func grantBonusSmartPicks(_ count: Int) {
        freeSmartUsesRemainingToday += count
    }
    
    /// Grant bonus shuffles
    func grantBonusShuffles(_ count: Int) {
        freeShufflesRemainingToday += count
    }
    
    // MARK: - Feature Access Checks
    
    func canAccessFeature(_ feature: PremiumFeature) -> Bool {
        if isPlus || isInTrial {
            return true
        }
        
        switch feature {
        case .unlimitedSmartPicks:
            return freeSmartUsesRemainingToday > 0
        case .unlimitedShuffles:
            return freeShufflesRemainingToday > 0
        case .hiddenGems, .advancedFilters, .actorDirectorSearch, .customRuntime:
            return false
        case .filterPresets:
            return freeFilterSavesRemaining > 0
        }
    }
    
    // MARK: - Upsell Messaging
    
    var personalizedUpsellMessage: String {
        if hasExhaustedFreeTier {
            return "You've used all your free smart picks today. Upgrade for unlimited!"
        } else if isHeavyUser {
            return "You've discovered \(totalMoviesDiscovered) movies! Unlock unlimited access."
        } else if isFrequentUser {
            return "You're on a roll! Get unlimited features to keep discovering."
        } else if eligibleForTrial {
            return "Try FilmFuel+ free for \(trialDurationDays) days!"
        } else {
            return "Upgrade to unlock all features and unlimited smart picks."
        }
    }
    
    var urgentUpsellMessage: String? {
        if freeSmartUsesRemainingToday == 1 {
            return "Only 1 smart pick left today!"
        } else if freeSmartUsesRemainingToday == 0 {
            return "No smart picks remaining. Upgrade now!"
        } else if trialDaysRemaining == 1 && isInTrial {
            return "Trial ends tomorrow! Subscribe to keep Plus features."
        }
        return nil
    }
}

// MARK: - Premium Features

enum PremiumFeature: String, CaseIterable {
    case unlimitedSmartPicks
    case unlimitedShuffles
    case hiddenGems
    case advancedFilters
    case actorDirectorSearch
    case customRuntime
    case filterPresets
    
    var displayName: String {
        switch self {
        case .unlimitedSmartPicks: return "Unlimited Smart Picks"
        case .unlimitedShuffles:   return "Unlimited Shuffles"
        case .hiddenGems:          return "Hidden Gems Mode"
        case .advancedFilters:     return "Advanced Filters"
        case .actorDirectorSearch: return "Actor/Director Search"
        case .customRuntime:       return "Custom Runtime Filter"
        case .filterPresets:       return "Saved Filter Presets"
        }
    }
    
    var icon: String {
        switch self {
        case .unlimitedSmartPicks: return "infinity"
        case .unlimitedShuffles:   return "shuffle"
        case .hiddenGems:          return "diamond.fill"
        case .advancedFilters:     return "slider.horizontal.3"
        case .actorDirectorSearch: return "person.fill.questionmark"
        case .customRuntime:       return "timer"
        case .filterPresets:       return "star.fill"
        }
    }
}
