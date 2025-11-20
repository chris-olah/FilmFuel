import Foundation
import StoreKit
import UIKit

final class RateManager {

    static let shared = RateManager()

    private let defaults = UserDefaults.standard

    private let installDateKey = "ff.rate.installDate"
    private let triviaCompletionsKey = "ff.rate.triviaCompletions"
    private let favoritesCountKey = "ff.rate.favoritesCount"
    private let promptCountKey = "ff.rate.promptCount"
    private let lastPromptDateKey = "ff.rate.lastPromptDate"

    // MARK: - Configurable thresholds (production)
    private let minDaysSinceInstall = 3
    private let minTriviaCompletionsForPrompt = 3
    private let minFavoritesForPrompt = 5
    private let minDaysBetweenPrompts = 30
    private let maxTotalPrompts = 3

    private init() {
        ensureInstallDate()
    }

    // MARK: - Public event hooks

    /// Call when user completes a trivia round (e.g., daily trivia or More Trivia)
    func trackTriviaCompleted() {
        let newCount = defaults.integer(forKey: triviaCompletionsKey) + 1
        defaults.set(newCount, forKey: triviaCompletionsKey)
        maybeRequestReview(reason: "triviaCompleted")
    }

    /// Call when user favorites a quote (from Discover or elsewhere)
    func trackQuoteFavorited() {
        let newCount = defaults.integer(forKey: favoritesCountKey) + 1
        defaults.set(newCount, forKey: favoritesCountKey)
        maybeRequestReview(reason: "favoriteAdded")
    }

    /// Optional: call when Favorites screen is opened and user has some saved quotes
    func trackFavoritesOpened() {
        maybeRequestReview(reason: "favoritesOpened")
    }

    // MARK: - Core logic

    private func ensureInstallDate() {
        if defaults.object(forKey: installDateKey) as? Date == nil {
            defaults.set(Date(), forKey: installDateKey)
        }
    }

    private func daysSince(_ date: Date) -> Int {
        let cal = Calendar.current
        let startOfNow = cal.startOfDay(for: Date())
        let startOfThen = cal.startOfDay(for: date)
        return cal.dateComponents([.day], from: startOfThen, to: startOfNow).day ?? 0
    }

    private func isEligibleToPrompt() -> Bool {

        // Must have an install date
        guard let installDate = defaults.object(forKey: installDateKey) as? Date else {
            return false
        }

        // App should be installed for at least N days
        if daysSince(installDate) < minDaysSinceInstall {
            return false
        }

        // Don't show more than N total prompts
        if defaults.integer(forKey: promptCountKey) >= maxTotalPrompts {
            return false
        }

        // Respect cooldown between prompts
        if let lastPrompt = defaults.object(forKey: lastPromptDateKey) as? Date {
            if daysSince(lastPrompt) < minDaysBetweenPrompts {
                return false
            }
        }

        return true
    }

    private func meetsBehaviorThresholds() -> Bool {
        let trivia = defaults.integer(forKey: triviaCompletionsKey)
        let favorites = defaults.integer(forKey: favoritesCountKey)

        // Either they've played enough trivia or saved enough quotes
        if trivia >= minTriviaCompletionsForPrompt { return true }
        if favorites >= minFavoritesForPrompt { return true }

        return false
    }

    private func maybeRequestReview(reason: String) {
        // Global guard rails
        guard isEligibleToPrompt(), meetsBehaviorThresholds() else {
            return
        }

        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else {
                return
            }

            // iOS 18+: use AppStore.requestReview(in:)
            if #available(iOS 18.0, *) {
                AppStore.requestReview(in: scene)
            } else {
                // iOS 10.3–17: use SKStoreReviewController
                SKStoreReviewController.requestReview(in: scene)
            }

            // Record that we prompted
            let newCount = self.defaults.integer(forKey: self.promptCountKey) + 1
            self.defaults.set(newCount, forKey: self.promptCountKey)
            self.defaults.set(Date(), forKey: self.lastPromptDateKey)
        }
    }
}
