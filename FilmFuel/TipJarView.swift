import SwiftUI
import StoreKit

struct TipJarView: View {
    @StateObject private var store = TipJarStore()

    @State private var showingCustomSheet = false
    @State private var selectedProductID: Product.ID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                headerSection

                if store.isLoading {
                    ProgressView("Loading tip options…")
                        .padding(.top, 8)
                } else if let message = store.errorMessage {
                    errorSection(message: message)
                } else if store.products.isEmpty {
                    Text("Tip options are not available right now.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                } else {
                    quickTipsSection
                    customTipSection
                }

                if let product = store.lastThankedProduct {
                    thankYouBanner(for: product)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Tip Jar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingCustomSheet) {
                customTipSheet
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "popcorn.fill")
                .font(.system(size: 40))
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(Circle())

            Text("Fuel the Fuel")
                .font(.title2)
                .fontWeight(.semibold)

            Text("If FilmFuel gives you a little motivation or joy, you can leave a tip to support future updates. Totally optional – the app works the same either way.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.top)
    }

    private func errorSection(message: String) -> some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await store.loadProducts()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 8)
    }

    /// A small set of one-tap tips (e.g. tiny / small / medium).
    private var quickTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Tips")
                .font(.headline)

            // Use first 3 as “quick” suggestions by price.
            let quickProducts = Array(store.products.prefix(3))

            ForEach(quickProducts, id: \.id) { product in
                Button {
                    Task {
                        await store.purchase(product)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(labelFor(product: product))
                                .font(.headline)
                            Text("One-time tip")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(product.displayPrice)
                            .font(.headline)

                        if store.isPurchasing {
                            ProgressView()
                                .padding(.leading, 4)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
                .disabled(store.isPurchasing)
            }
        }
        .padding(.top, 8)
    }

    /// Button to open the custom amount picker (uses *all* products).
    private var customTipSection: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.vertical, 4)

            Button {
                showingCustomSheet = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Choose Any Amount")
                            .font(.headline)
                        Text("Pick from all available tip amounts, including under a dollar or bigger tips.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "slider.horizontal.3")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.tertiarySystemBackground))
                )
            }
            .buttonStyle(.plain)
            .disabled(store.products.isEmpty || store.isPurchasing)

            Text("Tips are handled securely by the App Store. We never see your payment details.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private func thankYouBanner(for product: Product) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.headline)

            VStack(alignment: .leading, spacing: 2) {
                Text("Thank you!")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Your \(product.displayName.lowercased()) helps keep FilmFuel going. 🎬")
                    .font(.caption)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemGreen).opacity(0.15))
        )
        .padding(.top, 8)
    }

    // MARK: - Custom Tip Sheet

    private var customTipSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if store.products.isEmpty {
                    Text("No tip options are available right now.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let sorted = store.products.sorted { $0.price < $1.price }

                    Picker("Tip amount", selection: $selectedProductID) {
                        ForEach(sorted, id: \.id) { product in
                            Text("\(product.displayPrice) – \(labelFor(product: product))")
                                .tag(product.id as Product.ID?)
                        }
                    }
                    .pickerStyle(.wheel)
                    .onAppear {
                        if selectedProductID == nil {
                            selectedProductID = sorted.first?.id
                        }
                    }

                    Button {
                        guard
                            let id = selectedProductID,
                            let product = store.products.first(where: { $0.id == id })
                        else { return }

                        Task {
                            await store.purchase(product)
                            // If purchase succeeds, the thank-you banner will update in the main view.
                        }
                    } label: {
                        Text("Tip This Amount")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isPurchasing)
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Custom Tip")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        showingCustomSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Nice label names based on product IDs.
    private func labelFor(product: Product) -> String {
        switch product.id {
        case "tip.tiny":
            return "Tiny Tip"
        case "tip.small":
            return "Small Tip"
        case "tip.medium":
            return "Medium Tip"
        case "tip.large":
            return "Large Tip"
        case "tip.big":
            return "Big Tip"
        case "tip.huge":
            return "Huge Tip"
        default:
            return product.displayName
        }
    }
}

struct TipJarView_Previews: PreviewProvider {
    static var previews: some View {
        TipJarView()
    }
}
