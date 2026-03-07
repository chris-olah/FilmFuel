//
//  WantToWatchView.swift
//  FilmFuel
//

import SwiftUI

struct WantToWatchView: View {
    @EnvironmentObject var discoverVM: DiscoverVM
    @EnvironmentObject var entitlements: FilmFuelEntitlements
    @EnvironmentObject var store: FilmFuelStore

    @State private var selectedMovie: TMDBMovie? = nil
    @State private var searchText: String = ""
    @State private var appeared = false
    @State private var sortOrder: SortOrder = .dateAdded

    enum SortOrder: String, CaseIterable {
        case dateAdded = "Recently Added"
        case rating    = "Highest Rated"
        case title     = "A–Z"

        var icon: String {
            switch self {
            case .dateAdded: return "clock.fill"
            case .rating:    return "star.fill"
            case .title:     return "textformat.abc"
            }
        }
    }

    private var filteredMovies: [TMDBMovie] {
        let base: [TMDBMovie]
        switch sortOrder {
        case .dateAdded:
            base = discoverVM.watchlistMovies
        case .rating:
            base = discoverVM.watchlistMovies.sorted { $0.voteAverage > $1.voteAverage }
        case .title:
            base = discoverVM.watchlistMovies.sorted { $0.title < $1.title }
        }

        guard !searchText.isEmpty else { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if discoverVM.watchlistMovies.isEmpty {
                emptyState
            } else {
                movieList
            }
        }
        .navigationTitle("Want to Watch")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
        .searchable(text: $searchText, prompt: "Search your watchlist")
        .sheet(item: $selectedMovie) { movie in
            NavigationStack {
                MovieDetailView(movie: movie)
                    .environmentObject(discoverVM)
                    .environmentObject(entitlements)
                    .environmentObject(store)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Movie List

    private var movieList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Stats bar
                statsBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Movie rows
                ForEach(Array(filteredMovies.enumerated()), id: \.element.id) { index, movie in
                    WatchlistRow(
                        movie: movie,
                        index: index,
                        appeared: appeared,
                        onTap: { selectedMovie = movie },
                        onRemove: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                discoverVM.removeFromWatchlist(movie)
                            }
                        },
                        onMarkSeen: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                discoverVM.toggleSeen(movie)
                                discoverVM.removeFromWatchlist(movie)
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }

                if filteredMovies.isEmpty && !searchText.isEmpty {
                    noSearchResults
                }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 12) {
            statPill(
                value: "\(discoverVM.watchlistMovies.count)",
                label: "saved",
                icon: "bookmark.fill",
                color: .accentColor
            )

            if let avgRating = averageRating {
                statPill(
                    value: String(format: "%.1f", avgRating),
                    label: "avg rating",
                    icon: "star.fill",
                    color: .yellow
                )
            }

            Spacer()
        }
    }

    private func statPill(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private var averageRating: Double? {
        let movies = discoverVM.watchlistMovies.filter { $0.voteAverage > 0 }
        guard !movies.isEmpty else { return nil }
        return movies.map(\.voteAverage).reduce(0, +) / Double(movies.count)
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(SortOrder.allCases, id: \.rawValue) { order in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sortOrder = order
                    }
                } label: {
                    Label(order.rawValue, systemImage: order.icon)
                    if sortOrder == order {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.body.weight(.medium))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.2), .accentColor.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)

                Image(systemName: "bookmark.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.accentColor)
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 8) {
                Text("Your watchlist is empty")
                    .font(.title3.weight(.semibold))

                Text("Tap the bookmark icon on any movie\nto save it here for later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
        .padding(40)
    }

    // MARK: - No Search Results

    private var noSearchResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No results for \"\(searchText)\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 60)
    }
}

// MARK: - Watchlist Row

private struct WatchlistRow: View {
    let movie: TMDBMovie
    let index: Int
    let appeared: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    let onMarkSeen: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Poster
                posterView

                // Info
                VStack(alignment: .leading, spacing: 5) {
                    Text(movie.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        if let year = movie.releaseYear {
                            Text(year)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if movie.voteAverage > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", movie.voteAverage))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    genreChips
                }

                Spacer(minLength: 0)

                // Actions
                VStack(spacing: 8) {
                    // Mark seen
                    Button(action: onMarkSeen) {
                        Image(systemName: "eye.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .frame(width: 32, height: 32)
                            .background(Color.green.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    // Remove
                    Button(action: onRemove) {
                        Image(systemName: "bookmark.slash.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.82)
                .delay(Double(index) * 0.04),
            value: appeared
        )
    }

    private var posterView: some View {
        AsyncImage(url: movie.posterURL) { phase in
            switch phase {
            case .empty:
                posterPlaceholder
                    .overlay { ProgressView().scaleEffect(0.7) }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                posterPlaceholder
            @unknown default:
                posterPlaceholder
            }
        }
        .frame(width: 60, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var posterPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(.tertiarySystemBackground), Color(.secondarySystemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "film")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
    }

    private var genreChips: some View {
        let genreNames: [String] = (movie.genreIDs ?? []).prefix(2).compactMap {
            DiscoverVM.genreNameByID[$0]
        }

        return HStack(spacing: 6) {
            ForEach(genreNames, id: \.self) { name in
                Text(name)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - TMDBMovie convenience

private extension TMDBMovie {
    var releaseYear: String? {
        guard let date = releaseDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
}

#Preview {
    NavigationStack {
        WantToWatchView()
            .environmentObject(DiscoverVM(client: TMDBClient()))
            .environmentObject(FilmFuelEntitlements())
            .environmentObject(FilmFuelStore())
    }
}
