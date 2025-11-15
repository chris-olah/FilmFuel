import Foundation
import StoreKit
import Combine

@MainActor
final class TipJarStore: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var isPurchasing: Bool = false
    @Published var lastThankedProduct: Product?
    @Published var errorMessage: String?

    /// Your product IDs from App Store Connect.
    /// Make sure these exactly match the IDs you created there.
    private let productIDs: [String] = [
        "tip.popcorn1",  // Popcorn Treat
        "tip.popcorn2",  // Popcorn Refill
        "tip.popcorn3",  // Movie Night Combo
        "tip.popcorn4",  // Deluxe Popcorn Bucket
        "tip.popcorn5"   // Blockbuster Support
    ]

    init() {
        Task {
            await loadProducts()
        }
    }

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let storeProducts = try await Product.products(for: productIDs)

            // Sort by price ascending so the UI and picker feel natural.
            let sorted = storeProducts.sorted { $0.price < $1.price }
            self.products = sorted
        } catch {
            self.errorMessage = "Unable to load tip options right now. Please try again later."
            print("TipJarStore loadProducts error: \(error)")
        }

        isLoading = false
    }

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    lastThankedProduct = product

                case .unverified(_, let error):
                    errorMessage = "There was a problem verifying your purchase."
                    print("Unverified transaction: \(error.localizedDescription)")
                }

            case .userCancelled:
                // User backed out of the purchase sheet.
                break

            case .pending:
                errorMessage = "Your purchase is pending."

            @unknown default:
                break
            }
        } catch {
            errorMessage = "Something went wrong while processing the purchase."
            print("TipJarStore purchase error: \(error)")
        }

        isPurchasing = false
    }
}
