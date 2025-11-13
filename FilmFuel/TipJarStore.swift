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
    /// Set their prices there (e.g. $0.49, $0.99, $1.99, $4.99, $6.99, $9.99, etc.).
    private let productIDs: [String] = [
        "tip.tiny",    // under a dollar, e.g. $0.49
        "tip.small",   // e.g. $0.99
        "tip.medium",  // e.g. $2.99
        "tip.large",   // e.g. $4.99
        "tip.big",     // e.g. $6.99
        "tip.huge"     // e.g. $9.99
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
