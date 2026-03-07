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

    private var sortedProducts: [Product] {
        manager.products.sorted { a, b in
            let aIsYearly = a.id.lowercased().contains("year")
            let bIsYearly = b.id.lowercased().contains("year")
            if aIsYearly != bIsYearly { return aIsYearly }
            return a.displayPrice < b.displayPrice
        }
    }

    private func isYearly(_ product: Product) -> Bool {
        product.id.lowercased().contains("year")
    }

    private func productTypeLabel(for product: Product) -> String {
        if isYearly(product) { return "Yearly plan" }
        return "Monthly plan"
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
        let yearly = isYearly(product)

        return Button {
            Task { await manager.purchase(product) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(product.displayName)
                        .font(.headline)

                    Spacer()

                    if yearly {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Best value")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.yellow.opacity(0.9))
                                .foregroundColor(.black)
                                .clipShape(Capsule())

                            Text("Save 58%")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                Text(productTypeLabel(for: product))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if yearly {
                    Text("Just \(product.displayPrice)/year — that's less than a coffee a month.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Flexibility to enjoy FilmFuel+ month by month.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(product.displayPrice)
                        .font(.title3.bold())

                    if yearly {
                        Text("/ year")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("/ month")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
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
                    .strokeBorder(
                        yearly ? Color.yellow.opacity(0.9) : Color.white.opacity(0.18),
                        lineWidth: yearly ? 2 : 1
                    )
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
