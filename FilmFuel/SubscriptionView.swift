//
//  SubscriptionView.swift
//  FilmFuel
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = SubscriptionManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    header

                    if manager.isLoading {
                        ProgressView("Loading options…")
                            .tint(.white)
                            .padding(.top, 16)
                    } else if manager.products.isEmpty {
                        Text("No subscription options are available right now.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 16)
                    } else {
                        // Show yearly first as "best value", then monthly
                        ForEach(sortedProducts, id: \.id) { product in
                            productCard(product)
                        }
                    }

                    if manager.isSubscribed, let active = manager.currentSubscription {
                        Text("Active: \(active.displayName) • \(active.displayPrice)")
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .padding(.top, 4)
                    }

                    Button("Restore Purchases") {
                        Task {
                            await manager.restorePurchases()
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.top, 8)

                    Spacer()

                    footerText
                }
                .padding()
                .foregroundColor(.white)
            }
            .navigationTitle("FilmFuel+")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await manager.loadProducts()
            }
        }
    }

    // MARK: - Helpers

    /// Prefer showing yearly first as the "best value"
    private var sortedProducts: [Product] {
        manager.products.sorted { a, b in
            let aID = a.id.lowercased()
            let bID = b.id.lowercased()

            let aIsYearly = aID.contains("year")
            let bIsYearly = bID.contains("year")

            if aIsYearly != bIsYearly {
                return aIsYearly && !bIsYearly
            }

            // Otherwise sort by price
            return a.displayPrice < b.displayPrice
        }
    }

    private func productTypeLabel(for product: Product) -> String {
        let id = product.id.lowercased()
        if id.contains("year") {
            return "Yearly plan"
        } else if id.contains("month") {
            return "Monthly plan"
        } else {
            return "Subscription"
        }
    }

    private func productTagline(for product: Product) -> String {
        let id = product.id.lowercased()
        if id.contains("year") {
            return "Best value for FilmFuel+ all year long."
        } else if id.contains("month") {
            return "Flexibility to enjoy FilmFuel+ month by month."
        } else {
            return "Unlock full FilmFuel+ access."
        }
    }

    private func isBestValue(_ product: Product) -> Bool {
        product.id.lowercased().contains("year")
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "popcorn.fill")
                .font(.largeTitle)
                .padding(12)
                .background(.ultraThickMaterial)
                .clipShape(Circle())

            Text("Unlock FilmFuel+")
                .font(.title2.bold())

            Text("Smarter Discover, more trivia, and extra goodies to fuel your movie obsession.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private func productCard(_ product: Product) -> some View {
        let bestValue = isBestValue(product)

        return Button {
            Task {
                await manager.purchase(product)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(product.displayName)
                        .font(.headline)

                    if bestValue {
                        Spacer()
                        Text("Best value")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.9))
                            .foregroundColor(.black)
                            .clipShape(Capsule())
                    }
                }

                Text(productTypeLabel(for: product))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(productTagline(for: product))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(product.displayPrice)
                    .font(.title3.bold())
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(bestValue ? Color.yellow.opacity(0.9) : Color.white.opacity(0.18),
                                  lineWidth: bestValue ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var footerText: some View {
        VStack(spacing: 4) {
            Text("You can cancel anytime in your App Store account settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Subscriptions auto-renew unless canceled at least 24 hours before the end of the current period.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 4)
    }
}
