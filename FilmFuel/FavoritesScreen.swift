//
//  FavoritesScreen.swift
//  FilmFuel
//
//  Created by Chris Olah on 11/14/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Local favorites store (matches DiscoverView)
private enum FavoritesStore {
    private static let key = "ff.discover.favorites"

    static func load() -> Set<String> {
        if let data = UserDefaults.standard.array(forKey: key) as? [String] {
            return Set(data)
        }
        return []
    }

    static func save(_ set: Set<String>) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

// Helper to match DiscoverView key format
private func favoriteKey(for q: Quote) -> String {
    "\(q.movie)|\(q.year)|\(q.text)"
}

// MARK: - Favorites Screen

struct FavoritesScreen: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var favoriteKeys: Set<String> = FavoritesStore.load()
    @State private var allQuotes: [Quote] = []

    @State private var showingShare = false
    @State private var pendingShareText: String = ""

    private let repo = QuotesRepository(jsonFileName: "quotes")

    // Derived: Only quotes that match the saved keys
    private var favoriteQuotes: [Quote] {
        let keys = favoriteKeys
        return allQuotes
            .filter { keys.contains(favoriteKey(for: $0)) }
            .sorted { $0.movie.localizedCaseInsensitiveCompare($1.movie) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if favoriteQuotes.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 14) {
                        ForEach(favoriteQuotes, id: \.text) { quote in
                            FavoriteQuoteCard(
                                quote: quote,
                                onShare: { share(quote) },
                                onRemove: { remove(quote) }
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle("Saved Quotes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShare) {
            ShareSheet(activityItems: [pendingShareText])
        }
        .onAppear {
            allQuotes = repo.quotes
            favoriteKeys = FavoritesStore.load()
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("No saved quotes yet")
                .font(.headline)

            Text("Browse Discover and tap the heart to save your favorite movie quotes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Actions

    private func share(_ q: Quote) {
        pendingShareText = "“\(q.text)” — \(q.movie) (\(q.year)) #FilmFuel"
        showingShare = true
    }

    private func remove(_ q: Quote) {
        let key = favoriteKey(for: q)
        favoriteKeys.remove(key)
        FavoritesStore.save(favoriteKeys)

        // Immediate UI update
        allQuotes = repo.quotes
    }
}

// MARK: - Quote Card

private struct FavoriteQuoteCard: View {
    let quote: Quote
    let onShare: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Quote text
            Text("“\(quote.text)”")
                .font(.headline.weight(.semibold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // Movie + year row
            HStack(spacing: 6) {
                Image(systemName: "film")
                    .imageScale(.small)
                Text(quote.movie)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text("• \(String(quote.year))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Divider().opacity(0.15)

            // Buttons
            HStack(spacing: 12) {
                Button(action: onShare) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive, action: onRemove) {
                    Label("Remove", systemImage: "heart.slash")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .shadow(radius: 4, y: 2)
    }
}
