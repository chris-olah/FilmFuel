//
//  SubscriptionView.swift
//  FilmFuel
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = SubscriptionManager.shared
    @State private var selectedProductID: String? = nil

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("sparkles", "Smart Discover", "AI-powered picks based on your taste"),
        ("questionmark.bubble.fill", "Deep Trivia", "Unlock hundreds of behind-the-scenes questions"),
        ("bookmark.fill", "Unlimited Watchlists", "Organize every film you love or want to see"),
        ("bell.badge.fill", "Release Alerts", "Never miss a film you're waiting for"),
        ("xmark.circle.fill", "No Ads", "Pure, distraction-free browsing")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.06, blue: 0.02), Color.black],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header
                            .padding(.top, 8)
                            .padding(.bottom, 28)

                        featureList
                            .padding(.bottom, 28)

                        if manager.isLoading {
                            ProgressView("Loading options…")
                                .tint(.white)
                                .padding(.vertical, 24)
                        } else if manager.products.isEmpty {
                            Text("No subscription options available right now.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 24)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(sortedProducts, id: \.id) { product in
                                    productCard(product)
                                }
                            }
                        }

                        if manager.isSubscribed, let active = manager.currentSubscription {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                Text("Active: \(active.displayName) · \(active.displayPrice)")
                                    .foregroundStyle(.green)
                            }
                            .font(.footnote.weight(.medium))
                            .padding(.top, 16)
                        }

                        restoreButton
                            .padding(.top, 20)

                        footerText
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("FilmFuel+")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .task {
                await manager.loadProducts()
                // Default-select yearly if available
                if let yearly = manager.products.first(where: { $0.id.lowercased().contains("year") }) {
                    selectedProductID = yearly.id
                } else {
                    selectedProductID = manager.products.first?.id
                }
            }
        }
    }

    // MARK: - Sorted Products

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

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(Color.orange.opacity(0.08))
                    .frame(width: 92, height: 92)
                Image(systemName: "popcorn.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.bottom, 4)

            Text("Upgrade to FilmFuel+")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Everything a true film lover needs,\nin one place.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    // MARK: - Feature List

    private var featureList: some View {
        VStack(spacing: 0) {
            ForEach(features, id: \.title) { feature in
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: feature.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(feature.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(feature.subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    Spacer()

                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green.opacity(0.85))
                }
                .padding(.vertical, 11)

                if feature.title != features.last?.title {
                    Divider()
                        .background(Color.white.opacity(0.07))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
        )
    }

    // MARK: - Product Card

    private func productCard(_ product: Product) -> some View {
        let yearly = isYearly(product)
        let isSelected = selectedProductID == product.id

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedProductID = product.id
            }
            Task { await manager.purchase(product) }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(yearly ? "Yearly" : "Monthly")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            if yearly {
                                Text("BEST VALUE")
                                    .font(.system(size: 9, weight: .black))
                                    .tracking(0.8)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(
                                        LinearGradient(
                                            colors: [.orange, .yellow],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundStyle(.black)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(yearly
                             ? "Billed once a year — cancel anytime"
                             : "Billed monthly — cancel anytime")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    Spacer()

                    // Selection indicator
                    ZStack {
                        Circle()
                            .strokeBorder(
                                isSelected
                                ? LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 2
                            )
                            .frame(width: 22, height: 22)

                        if isSelected {
                            Circle()
                                .fill(
                                    LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 13, height: 13)
                        }
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.08))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(yearly ? "/ year" : "/ month")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.4))

                    Spacer()

                    if yearly {
                        Text("Save 58%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }

                if yearly {
                    Text("That's less than a coffee per month for everything FilmFuel+ offers.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .lineSpacing(2)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isSelected
                        ? Color.white.opacity(0.09)
                        : Color.white.opacity(0.04)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected
                        ? (yearly
                            ? LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.0 : 0.99)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            Task { await manager.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Footer

    private var footerText: some View {
        VStack(spacing: 5) {
            Text("Cancel anytime in your App Store account settings.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)

            Text("Subscriptions auto-renew unless canceled at least 24 hours before the end of the current period.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.22))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
    }
}
