//
//  FilmFuelPlusPaywallView.swift
//  FilmFuel
//

import SwiftUI
import StoreKit

struct FilmFuelPlusPaywallView: View {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject var store: FilmFuelStore
    @EnvironmentObject var entitlements: FilmFuelEntitlements

    @State private var isPurchasing: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        featureList
                        planOptions

                        if let message = store.purchaseErrorMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }

                        if let state = store.lastPurchaseStateDescription {
                            Text(state)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }

                bottomButtons
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
            .onChange(of: store.isPlus) { _, newValue in
                if newValue {
                    entitlements.isPlus = true
                    dismiss()
                }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "popcorn")
                .font(.system(size: 40))
            Text("Fuel your movie obsession")
                .font(.title3.weight(.semibold))
            Text("Unlock all trivia packs, smarter Discover, and premium goodies.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 16)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What you get with FilmFuel+")
                .font(.headline)

            featureRow("All current & future trivia packs")
            featureRow("Unlimited endless trivia")
            featureRow("Smart Discover tailored to your taste")
            featureRow("Advanced filters & moods")
            featureRow("Premium widgets and icons")
            featureRow("Early access to new features")
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.accentColor)
            Text(text)
                .font(.subheadline)
        }
    }

    private var planOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your plan")
                .font(.headline)
                .padding(.top, 8)

            if store.plusProducts.isEmpty {
                Text("Loading plans…")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(store.plusProducts, id: \.id) { product in
                    planCard(for: product)
                }
            }
        }
    }

    private func planCard(for product: Product) -> some View {
        Button {
            Task { await purchase(product) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(planTitle(for: product))
                        .font(.subheadline.weight(.semibold))
                    Text(planSubtitle(for: product))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.subheadline.weight(.semibold))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private func planTitle(for product: Product) -> String {
        if product.id.contains("year") || product.subscription?.subscriptionPeriod.unit == .year {
            return "Yearly – Best value"
        } else {
            return "Monthly"
        }
    }

    private func planSubtitle(for product: Product) -> String {
        if product.id.contains("year") || product.subscription?.subscriptionPeriod.unit == .year {
            return "Save more with a year of FilmFuel+."
        } else {
            return "Flexibility, billed every month."
        }
    }

    private var bottomButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task { await store.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.footnote.weight(.medium))
            }

            Text("You can cancel anytime in your App Store account settings.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Purchase helper

    private func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        await store.purchase(product)
    }
}
