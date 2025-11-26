//
//  MovieDetailVM.swift
//  FilmFuel
//

import Foundation
import SwiftUI
import Combine

// MARK: - Lightweight watch provider model for UI

struct MovieWatchProvider: Identifiable, Hashable {
    let id: Int            // TMDB provider ID
    let name: String       // e.g. "Netflix", "Disney+"
    let logoPath: String?  // TMDB logo path if you want to use it later
}

@MainActor
final class MovieDetailVM: ObservableObject {

    // Input
    let movie: TMDBMovie
    private let client: TMDBClientProtocol

    // Loaded detail
    @Published var detail: TMDBMovieDetail?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Watch providers (for "Where to watch" section)
    @Published var watchProviders: [MovieWatchProvider] = []
    @Published var watchProvidersRegion: String?  // e.g. "US"

    init(movie: TMDBMovie, client: TMDBClientProtocol) {
        self.movie = movie
        self.client = client
    }

    // MARK: - Public loading

    func loadIfNeeded() async {
        // If we already have detail and providers, skip
        if detail != nil && !watchProviders.isEmpty { return }

        isLoading = true
        errorMessage = nil

        do {
            // Always load detail
            let detail = try await client.fetchMovieDetail(id: movie.id)
            self.detail = detail

            // Non-fatal: try to load watch providers
            await loadWatchProvidersSafely()
        } catch {
            print("❌ Movie detail load failed: \(error)")
            errorMessage = "Could not load details right now."
        }

        isLoading = false
    }

    // MARK: - Watch providers loading

    /// Non-fatal helper: if TMDB watch provider call fails, we just log it.
    private func loadWatchProvidersSafely() async {
        // Don’t spam API if we already have providers
        if !watchProviders.isEmpty { return }

        do {
            // Region you’re targeting; can make this dynamic later
            let regionCode = "US"

            // Uses your existing TMDBClientProtocol method:
            // func fetchWatchProviders(id: Int) async throws -> TMDBWatchProvidersResponse
            let response = try await client.fetchWatchProviders(id: movie.id)

            // Use your convenience helper to pick the region
            guard let region = response.region(regionCode) else {
                return
            }

            let flatrate = region.flatrate ?? []
            let rent = region.rent ?? []
            let buy = region.buy ?? []

            // Combine all unique providers (by providerId)
            var byID: [Int: TMDBWatchProvider] = [:]
            for p in flatrate { byID[p.providerId] = p }
            for p in rent { byID[p.providerId] = p }
            for p in buy { byID[p.providerId] = p }

            let mapped: [MovieWatchProvider] = byID.values.map {
                MovieWatchProvider(
                    id: $0.providerId,
                    name: $0.providerName,
                    logoPath: $0.logoPath
                )
            }
            .sorted { $0.name < $1.name }

            self.watchProviders = mapped
            self.watchProvidersRegion = regionCode

        } catch {
            print("❌ Watch providers load failed: \(error)")
            // Intentionally no user-facing error; detail screen still works fine.
        }
    }

    // MARK: - Basic display helpers

    var displayTitle: String {
        // Prefer detailed title if available & non-empty
        if let d = detail {
            let trimmed = d.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        // Fallback to base movie title
        let baseTrimmed = movie.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return baseTrimmed.isEmpty ? movie.title : baseTrimmed
    }

    var displayYearText: String {
        var sourceDate: String?

        if let d = detail {
            let trimmed = d.releaseDate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                sourceDate = trimmed
            }
        }

        if sourceDate == nil {
            if let baseDate = movie.releaseDate {
                let trimmed = baseDate.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sourceDate = trimmed
                }
            }
        }

        guard let s = sourceDate, s.count >= 4 else { return "—" }
        return String(s.prefix(4))
    }

    var displayVoteAverage: Double {
        if let d = detail, d.voteAverage > 0 {
            return d.voteAverage
        }
        return movie.voteAverage
    }

    var displayVoteCount: Int {
        if let d = detail, d.voteCount > 0 {
            return d.voteCount
        }
        return movie.voteCount
    }

    var headerImageURL: URL? {
        // Prefer detail backdrop, then base backdrop, then detail poster, then base poster
        if let d = detail {
            if let url = d.backdropURL {
                return url
            }
            if let url = d.posterURL {
                return url
            }
        }

        if let url = movie.backdropURL {
            return url
        }
        if let url = movie.posterURL {
            return url
        }
        return nil
    }

    var overviewText: String? {
        if let d = detail {
            let trimmed = d.overview.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        let fallback = movie.overview.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallback.isEmpty {
            return fallback
        }
        return nil
    }

    var runtimeText: String? {
        guard let d = detail,
              let runtimeMinutes = d.runtime,
              runtimeMinutes > 0 else {
            return nil
        }

        let hours = runtimeMinutes / 60
        let minutes = runtimeMinutes % 60

        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }

    /// Placeholder: not parsing actual regional certification right now.
    var certification: String? {
        return nil
    }

    /// TMDB link for "Where to watch" section.
    /// You can keep this as a small "See full list on TMDB" link if you want.
    var whereToWatchURL: URL? {
        URL(string: "https://www.themoviedb.org/movie/\(movie.id)")
    }

    // MARK: - Smart Match & Insights

    private var releaseYear: Int? {
        var sourceDate: String?

        if let d = detail {
            let trimmed = d.releaseDate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                sourceDate = trimmed
            }
        }

        if sourceDate == nil {
            if let baseDate = movie.releaseDate {
                let trimmed = baseDate.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sourceDate = trimmed
                }
            }
        }

        guard let s = sourceDate, s.count >= 4 else { return nil }
        return Int(s.prefix(4))
    }

    var smartMatchScore: Int {
        let rating = displayVoteAverage          // 0–10
        let votes = Double(displayVoteCount)     // 0–∞
        let year = releaseYear

        var score: Double = 0

        // Rating -> up to ~60 points
        score += (rating / 10.0) * 60.0

        // Votes boost
        if votes > 20000 {
            score += 20
        } else if votes > 5000 {
            score += 15
        } else if votes > 1000 {
            score += 10
        } else if votes > 200 {
            score += 5
        }

        // Recency boost
        if let y = year {
            let currentYear = Calendar.current.component(.year, from: Date())
            let age = max(0, currentYear - y)
            if age <= 1 {
                score += 10
            } else if age <= 5 {
                score += 7
            } else if age <= 15 {
                score += 3
            }
        }

        // Clamp 10–98
        let clamped = max(10, min(98, Int(score.rounded())))
        return clamped
    }

    var smartReasonLines: [String] {
        var reasons: [String] = []

        let rating = displayVoteAverage
        let votes = displayVoteCount
        if rating >= 8.2 {
            reasons.append("Critically loved with a standout audience score.")
        } else if rating >= 7.5 {
            reasons.append("Strong audience score above the typical movie.")
        }

        if votes > 20000 {
            reasons.append("Tons of people have rated this, so the score is very reliable.")
        } else if votes > 3000 {
            reasons.append("Well-established with thousands of audience ratings.")
        } else if votes > 500 {
            reasons.append("Solid amount of ratings from real viewers.")
        }

        if let year = releaseYear {
            let currentYear = Calendar.current.component(.year, from: Date())
            let age = max(0, currentYear - year)

            if age <= 1 {
                reasons.append("Very recent release, great if you want something new.")
            } else if age <= 5 {
                reasons.append("Modern era pick that still feels current.")
            } else if age >= 20 {
                reasons.append("Older title with potential cult-classic vibes.")
            }
        }

        if reasons.isEmpty {
            reasons.append("Balanced mix of rating, reviews, and release date.")
        }
        return reasons
    }

    // Static mapping so insights can use human-readable genre names if needed.
    private static let genreNameByID: [Int: String] = [
        28: "Action",
        12: "Adventure",
        16: "Animation",
        35: "Comedy",
        80: "Crime",
        99: "Documentary",
        18: "Drama",
        10751: "Family",
        14: "Fantasy",
        27: "Horror",
        10402: "Music",
        9648: "Mystery",
        10749: "Romance",
        878: "Sci-Fi",
        10770: "TV Movie",
        53: "Thriller",
        10752: "War",
        37: "Western"
    ]

    var quickInsights: [String] {
        var chips: [String] = []

        // Prefer detail genres if we have them, else the base genreIDs
        let ids: [Int] = {
            if let d = detail {
                return d.genres.map { $0.id }
            } else {
                return movie.genreIDs ?? []
            }
        }()

        let idSet = Set(ids)

        func has(_ g: Int) -> Bool { idSet.contains(g) }

        if has(27) {
            chips.append("Perfect for a spooky night in.")
        }
        if has(35) && has(10749) {
            chips.append("Great pick for a light date night.")
        } else if has(35) {
            chips.append("Good choice when you want something fun and light.")
        }
        if has(28) || has(12) || has(53) {
            chips.append("High-energy pick when you’re in an adrenaline mood.")
        }
        if has(18) {
            chips.append("Leans more dramatic and character-focused.")
        }
        if has(878) {
            chips.append("Sci-fi fans will probably have this on their radar.")
        }

        if let d = detail, let runtime = d.runtime, runtime > 0 {
            if runtime >= 150 {
                chips.append("Epic runtime — settle in for a long watch.")
            } else if runtime <= 100 {
                chips.append("On the shorter side, easy to fit into an evening.")
            }
        }

        if displayVoteAverage >= 8.5 {
            chips.append("One of the highest-rated titles in its category.")
        }

        // De-dupe
        var seen = Set<String>()
        let unique = chips.filter { chip in
            if seen.contains(chip) { return false }
            seen.insert(chip)
            return true
        }

        return unique
    }
}
