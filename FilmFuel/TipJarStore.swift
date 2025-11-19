//
//  TipJarStore.swift
//  FilmFuel
//
//  Created by Chris Olah on 11/19/25.
//

import Foundation
import StoreKit
import Combine

@MainActor
final class TipJarStore: ObservableObject {

    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var isPurchasing: Bool = false
    @Published var errorMessage: String?
    @Published var lastThankedProduct: Product?

    // MARK: - Product IDs (Option A)
    private let productIDs: [String] = [
        "tip.popcorn.small",   // Popcorn Treat
        "tip.popcorn.medium",  // Double Feature Tip
        "tip.popcorn.large"    // Blockbuster Boost
    ]

    init() {
        Task { await loadProducts() }
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let storeProducts = try await Product.products(for: Set(productIDs))

            let filtered = storeProducts
                .filter { productIDs.contains($0.id) }
                .sorted { $0.price < $1.price }

            products = filtered

            if filtered.isEmpty {
                errorMessage = "Tip options are not available right now."
            }

            print("Loaded \(filtered.count) Tip Jar products")
        } catch {
            print("TipJarStore: load error:", error.localizedDescription)
            errorMessage = "Unable to load tip options. Please try again."
            products = []
        }

        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                if let transaction = checkVerified(verificationResult) {
                    await transaction.finish()
                    if let match = products.first(where: { $0.id == transaction.productID }) {
                        lastThankedProduct = match
                    }
                } else {
                    errorMessage = "Purchase verification failed."
                }

            case .userCancelled:
                break

            case .pending:
                errorMessage = "Your purchase is pending."

            @unknown default:
                errorMessage = "Unexpected purchase outcome."
            }

        } catch {
            print("Purchase error:", error.localizedDescription)
            errorMessage = "Purchase failed. Please try again."
        }

        isPurchasing = false
    }

    // MARK: - Verification Helper

    private func checkVerified<T>(_ result: VerificationResult<T>) -> T? {
        switch result {
        case .unverified(_, let verificationError):
            print("Unverified transaction:", verificationError.localizedDescription)
            return nil

        case .verified(let signedType):
            return signedType
        }
    }
}
