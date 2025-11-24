//
//  FilmFuelStore.swift
//  FilmFuel
//
//  Manages FilmFuel+ subscriptions using StoreKit 2.
//  Uses product IDs: ff_plus_monthly, ff_plus_yearly
//

import Foundation
import StoreKit
import Combine

@MainActor
final class FilmFuelStore: ObservableObject {

    // MARK: - Public published state

    @Published var plusProducts: [Product] = []
    @Published var isPlus: Bool = false

    @Published var isLoading: Bool = false
    @Published var purchaseErrorMessage: String?
    @Published var lastPurchaseStateDescription: String?

    // MARK: - Product IDs

    /// Subscription product IDs defined in App Store Connect
    let plusProductIDs: Set<String> = [
        "ff_plus_monthly",
        "ff_plus_yearly"
    ]

    // MARK: - Init

    init() {
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

    // MARK: - Load products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: Array(plusProductIDs))
            // Sort by price ascending (typically monthly then yearly, but depends on pricing)
            self.plusProducts = products.sorted(by: { $0.price < $1.price })
        } catch {
            print("❌ Failed to load products: \(error)")
            purchaseErrorMessage = "Could not load FilmFuel+ options right now."
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        purchaseErrorMessage = nil
        lastPurchaseStateDescription = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                let transaction = try checkVerified(verificationResult)
                await handleVerifiedTransaction(transaction)

            case .userCancelled:
                lastPurchaseStateDescription = "Purchase cancelled."

            case .pending:
                lastPurchaseStateDescription = "Purchase pending…"

            @unknown default:
                lastPurchaseStateDescription = "Unknown purchase state."
            }

        } catch {
            print("❌ Purchase error: \(error)")
            purchaseErrorMessage = "Your purchase could not be completed."
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        purchaseErrorMessage = nil
        lastPurchaseStateDescription = nil

        var hasPlus = false

        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(entitlement) else { continue }

            if plusProductIDs.contains(transaction.productID),
               !transaction.isUpgraded {
                hasPlus = true
            }
        }

        isPlus = hasPlus
        lastPurchaseStateDescription = hasPlus
            ? "FilmFuel+ restored 🎬"
            : "No active FilmFuel+ subscription found."
    }

    // MARK: - Entitlement refresh

    private func refreshEntitlements() async {
        var hasPlus = false

        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(entitlement) else { continue }

            if plusProductIDs.contains(transaction.productID),
               !transaction.isUpgraded {
                hasPlus = true
            }
        }

        isPlus = hasPlus
    }

    // MARK: - Transaction updates listener

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            do {
                let transaction = try checkVerified(result)
                await handleVerifiedTransaction(transaction)
            } catch {
                print("❌ Transaction update verification failed: \(error)")
            }
        }
    }

    private func handleVerifiedTransaction(_ transaction: Transaction) async {
        if plusProductIDs.contains(transaction.productID) {
            // Active if not revoked and not expired (if expiration exists)
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
                lastPurchaseStateDescription = "FilmFuel+ active 🎬🍿"
            } else {
                isPlus = false
                lastPurchaseStateDescription = "FilmFuel+ expired."
            }
        }

        await transaction.finish()
    }

    // MARK: - Verification helper

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
