//
//  FilmFuelStore.swift
//  FilmFuel
//
//  StoreKit 2 implementation with analytics hooks for conversion optimization
//

import Foundation
import StoreKit
import Combine

@MainActor
final class FilmFuelStore: ObservableObject {
    
    // MARK: - Published State
    
    @Published var plusProducts: [Product] = []
    @Published var isPlus: Bool = false
    @Published var isLoading: Bool = false
    @Published var purchaseErrorMessage: String?
    @Published var lastPurchaseStateDescription: String?
    
    // Analytics state
    @Published var purchaseAttempts: Int = 0
    @Published var lastPurchaseAttemptDate: Date?
    
    // MARK: - Product IDs
    
    let plusProductIDs: Set<String> = [
        "ff_plus_monthly",
        "ff_plus_yearly"
    ]
    
    // MARK: - Analytics Keys
    
    private let analyticsPrefix = "ff.analytics."
    private var purchaseAttemptsKey: String { analyticsPrefix + "purchaseAttempts" }
    private var conversionSourceKey: String { analyticsPrefix + "lastConversionSource" }
    private var paywallViewsKey: String { analyticsPrefix + "paywallViews" }
    
    // MARK: - Init
    
    init() {
        loadAnalytics()
        Task {
            await initializeStore()
        }
    }
    
    // MARK: - Setup
    
    private func initializeStore() async {
        isLoading = true
        defer { isLoading = false }
        
        await loadProducts()
        await refreshEntitlements()
        await listenForTransactions()
    }
    
    private func loadAnalytics() {
        purchaseAttempts = UserDefaults.standard.integer(forKey: purchaseAttemptsKey)
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        do {
            let products = try await Product.products(for: Array(plusProductIDs))
            // Sort yearly first (typically better conversion)
            self.plusProducts = products.sorted { p1, p2 in
                p1.id.contains("yearly")
            }
        } catch {
            print("❌ Failed to load products: \(error)")
            purchaseErrorMessage = "Could not load subscription options."
        }
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product, source: ConversionSource = .unknown) async {
        purchaseErrorMessage = nil
        lastPurchaseStateDescription = nil
        
        // Track attempt
        purchaseAttempts += 1
        lastPurchaseAttemptDate = Date()
        UserDefaults.standard.set(purchaseAttempts, forKey: purchaseAttemptsKey)
        UserDefaults.standard.set(source.rawValue, forKey: conversionSourceKey)
        
        // Analytics event
        trackEvent(.purchaseAttempted, properties: [
            "product_id": product.id,
            "source": source.rawValue,
            "attempt_number": purchaseAttempts
        ])
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verificationResult):
                let transaction = try checkVerified(verificationResult)
                await handleVerifiedTransaction(transaction, source: source)
                
            case .userCancelled:
                lastPurchaseStateDescription = "Purchase cancelled"
                trackEvent(.purchaseCancelled, properties: ["product_id": product.id])
                
            case .pending:
                lastPurchaseStateDescription = "Purchase pending…"
                trackEvent(.purchasePending, properties: ["product_id": product.id])
                
            @unknown default:
                lastPurchaseStateDescription = "Unknown purchase state"
            }
            
        } catch {
            print("❌ Purchase error: \(error)")
            purchaseErrorMessage = "Purchase could not be completed. Please try again."
            trackEvent(.purchaseFailed, properties: [
                "product_id": product.id,
                "error": error.localizedDescription
            ])
        }
    }
    
    // MARK: - Restore
    
    func restorePurchases() async {
        purchaseErrorMessage = nil
        lastPurchaseStateDescription = nil
        
        trackEvent(.restoreAttempted, properties: [:])
        
        var hasPlus = false
        
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(entitlement) else { continue }
            
            if plusProductIDs.contains(transaction.productID), !transaction.isUpgraded {
                hasPlus = true
            }
        }
        
        isPlus = hasPlus
        lastPurchaseStateDescription = hasPlus
            ? "FilmFuel+ restored! 🎬"
            : "No active subscription found."
        
        trackEvent(.restoreCompleted, properties: ["found_subscription": hasPlus])
    }
    
    // MARK: - Entitlement Refresh
    
    private func refreshEntitlements() async {
        var hasPlus = false
        
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(entitlement) else { continue }
            
            if plusProductIDs.contains(transaction.productID), !transaction.isUpgraded {
                hasPlus = true
            }
        }
        
        isPlus = hasPlus
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            do {
                let transaction = try checkVerified(result)
                await handleVerifiedTransaction(transaction, source: .transactionUpdate)
            } catch {
                print("❌ Transaction verification failed: \(error)")
            }
        }
    }
    
    private func handleVerifiedTransaction(_ transaction: Transaction, source: ConversionSource = .unknown) async {
        if plusProductIDs.contains(transaction.productID) {
            let isActive: Bool = {
                if transaction.revocationDate != nil || transaction.revocationReason != nil {
                    return false
                }
                if let expirationDate = transaction.expirationDate {
                    return expirationDate > Date()
                }
                return true
            }()
            
            if isActive {
                isPlus = true
                lastPurchaseStateDescription = "Welcome to FilmFuel+! 🎬🍿"
                
                trackEvent(.purchaseCompleted, properties: [
                    "product_id": transaction.productID,
                    "source": source.rawValue
                ])
            } else {
                isPlus = false
                lastPurchaseStateDescription = "Subscription expired"
                
                trackEvent(.subscriptionExpired, properties: [
                    "product_id": transaction.productID
                ])
            }
        }
        
        await transaction.finish()
    }
    
    // MARK: - Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Paywall Analytics
    
    func recordPaywallView(trigger: PaywallTrigger) {
        let views = UserDefaults.standard.integer(forKey: paywallViewsKey) + 1
        UserDefaults.standard.set(views, forKey: paywallViewsKey)
        
        trackEvent(.paywallViewed, properties: [
            "trigger": trigger.rawValue,
            "view_count": views
        ])
    }
    
    // MARK: - Product Helpers
    
    var monthlyProduct: Product? {
        plusProducts.first { $0.id == "ff_plus_monthly" }
    }
    
    var yearlyProduct: Product? {
        plusProducts.first { $0.id == "ff_plus_yearly" }
    }
    
    var yearlySavingsPercentage: Int {
        guard let monthly = monthlyProduct,
              let yearly = yearlyProduct else { return 50 }
        
        let monthlyAnnualized = monthly.price * Decimal(12)
        let savings = (monthlyAnnualized - yearly.price) / monthlyAnnualized
        return NSDecimalNumber(decimal: savings * Decimal(100)).intValue
    }
    
    // MARK: - Analytics (stub for your analytics service)
    
    private func trackEvent(_ event: AnalyticsEvent, properties: [String: Any]) {
        // TODO: Send to your analytics service (Mixpanel, Amplitude, Firebase, etc.)
        print("📊 Analytics: \(event.rawValue) - \(properties)")
    }
    
    enum StoreError: Error {
        case failedVerification
    }
}

// MARK: - Analytics Types

enum AnalyticsEvent: String {
    case paywallViewed = "paywall_viewed"
    case purchaseAttempted = "purchase_attempted"
    case purchaseCompleted = "purchase_completed"
    case purchaseCancelled = "purchase_cancelled"
    case purchasePending = "purchase_pending"
    case purchaseFailed = "purchase_failed"
    case restoreAttempted = "restore_attempted"
    case restoreCompleted = "restore_completed"
    case subscriptionExpired = "subscription_expired"
    case trialStarted = "trial_started"
    case trialConverted = "trial_converted"
    case trialExpired = "trial_expired"
}

enum ConversionSource: String {
    case unknown = "unknown"
    case smartPickLimit = "smart_pick_limit"
    case shuffleLimit = "shuffle_limit"
    case filterLocked = "filter_locked"
    case modeLocked = "mode_locked"
    case streakReward = "streak_reward"
    case levelUpReward = "level_up_reward"
    case manualUpgrade = "manual_upgrade"
    case endOfFeed = "end_of_feed"
    case settingsPage = "settings_page"
    case transactionUpdate = "transaction_update"
}

enum PaywallTrigger: String {
    case smartPickExhausted = "smart_pick_exhausted"
    case shuffleExhausted = "shuffle_exhausted"
    case featureLocked = "feature_locked"
    case promoOffer = "promo_offer"
    case streakAtRisk = "streak_at_risk"
    case manualTap = "manual_tap"
    case endOfFeed = "end_of_feed"
    case trialExpiring = "trial_expiring"
}
