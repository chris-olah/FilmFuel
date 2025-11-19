//
//  TipJarView.swift
//  FilmFuel
//
//  Created by Chris Olah on 11/19/25.
//

import SwiftUI
import StoreKit

struct TipJarView: View {
    @StateObject private var store = TipJarStore()

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
        }
    }

    // MARK: - Header

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

    // MARK: - Error

    private func errorSection(message: String) -> some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task { await store.loadProducts() }
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 8)
    }

    // MARK: - Tip List (3 options)

    private var quickTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Tips")
                .font(.headline)

            let products = store.products.sorted { $0.price < $1.price }

            ForEach(products, id: \.id) { product in
                Button {
                    Task { await store.purchase(product) }
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
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
                .disabled(store.isPurchasing)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Thank You Banner

    private func thankYouBanner(for product: Product) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.headline)

            VStack(alignment: .leading, spacing: 2) {
                Text("Thank you!")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Your \(labelFor(product: product).lowercased()) helps keep FilmFuel going. 🎬")
                    .font(.caption)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGreen).opacity(0.15))
        )
        .padding(.top, 8)
    }

    // MARK: - Label Helper

    private func labelFor(product: Product) -> String {
        switch product.id {
        case "tip.popcorn.small":
            return "Popcorn Treat"
        case "tip.popcorn.medium":
            return "Double Feature Tip"
        case "tip.popcorn.large":
            return "Blockbuster Boost"
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
