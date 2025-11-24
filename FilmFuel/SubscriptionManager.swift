//
//  SubscriptionManager.swift
//  FilmFuel
//

import Foundation
import StoreKit
import Combine   // 👈 Needed for ObservableObject / @Published

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // Your real FilmFuel+ product IDs
    private let productIDs: [String] = [
        "ff_plus_monthly",
        "ff_plus_yearly"
    ]

    @Published var products: [Product] = []
    @Published var currentSubscription: Product?
    @Published var isSubscribed: Bool = false
    @Published var isLoading: Bool = false

    init() {
        listenForTransactionUpdates()
    }

    // MARK: - Load Products

    func loadProducts() async {
        guard !productIDs.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: productIDs)
            // Sort by price so monthly appears before yearly (or vice versa)
            self.products = storeProducts.sorted { $0.displayPrice < $1.displayPrice }
            await updateCustomerProductStatus()
        } catch {
            print("❌ Failed to load subscription products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    await updateCustomerProductStatus()
                    await transaction.finish()
                case .unverified(_, let error):
                    print("❌ Unverified transaction: \(String(describing: error))")
                }

            case .userCancelled, .pending:
                break

            @unknown default:
                break
            }

        } catch {
            print("❌ Purchase error: \(error)")
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateCustomerProductStatus()
        } catch {
            print("❌ Restore error: \(error)")
        }
    }

    // MARK: - Entitlement Check

    func updateCustomerProductStatus() async {
        var activeProductID: String?

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if productIDs.contains(transaction.productID) {
                    activeProductID = transaction.productID
                }
            case .unverified:
                continue
            }
        }

        await MainActor.run {
            if let id = activeProductID,
               let product = products.first(where: { $0.id == id }) {
                currentSubscription = product
                isSubscribed = true
            } else {
                currentSubscription = nil
                isSubscribed = false
            }
        }
    }

    // MARK: - Listen for StoreKit Updates

    private func listenForTransactionUpdates() {
        Task.detached { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    await self.updateCustomerProductStatus()
                    await transaction.finish()
                case .unverified:
                    continue
                }
            }
        }
    }
}
