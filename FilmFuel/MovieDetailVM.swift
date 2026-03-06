//
//  MovieDetailVM.swift
//  FilmFuel
//
//  UPDATED: Fetches real TMDB recommendations, loads certifications,
//  better error handling with retry, richer Smart Match insights,
//  loading states for each section, caching support
//

import Foundation
import SwiftUI
import Combine

// MARK: - Watch Provider Model

struct MovieWatchProvider: Identifiable, Hashable {
    let id: Int
    let name: String
    let logoPath: String?
    let type: ProviderType
    
    enum ProviderType: String {
        case stream = "Stream"
        case rent = "Rent"
        case buy = "Buy"
    }
    
    var logoURL: URL? {
        guard let path = logoPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w92\(path)")
    }
}

// MARK: - View Model

@MainActor
final class MovieDetailVM: ObservableObject {

    // Input
    let movie: TMDBMovie
    private let client: TMDBClientProtocol

    // MARK: - Published State
    
    // Core detail
    @Published var detail: TMDBMovieDetail?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Certification (e.g., "PG-13")
    @Published var certification: String?
    
    // Watch providers
    @Published var streamingProviders: [MovieWatchProvider] = []
    @Published var rentProviders: [MovieWatchProvider] = []
    @Published var buyProviders: [MovieWatchProvider] = []
    @Published var watchProvidersRegion: String?
    
    // TMDB Recommendations (better than local filtering)
    @Published var recommendations: [TMDBMovie] = []
    @Published var isLoadingRecommendations: Bool = false
    
    // Loading states for progressive UI
    @Published var hasLoadedProviders: Bool = false
    @Published var hasLoadedCertification: Bool = false
    
    // Retry state
    private var loadAttempts = 0
    private let maxRetries = 2

    // MARK: - Init

    @MainActor
    init(movie: TMDBMovie, client: TMDBClientProtocol = TMDBClient()) {
        self.movie = movie
        self.client = client
    }

    // MARK: - Public Loading

    func loadIfNeeded() async {
        guard detail == nil else { return }
        await loadAllData()
    }
    
    func retry() async {
        errorMessage = nil
        loadAttempts = 0
        await loadAllData()
    }
    
    private func loadAllData() async {
        isLoading = true
        errorMessage = nil

        do {
            // 1. Load core detail (required)
            let fetchedDetail = try await client.fetchMovieDetail(id: movie.id)
            self.detail = fetchedDetail
            
            // 2. Load secondary data in parallel (non-blocking)
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadCertificationSafely() }
                group.addTask { await self.loadWatchProvidersSafely() }
                group.addTask { await self.loadRecommendationsSafely() }
            }
            
        } catch {
            loadAttempts += 1
            print("❌ Movie detail load failed (attempt \(loadAttempts)): \(error)")
            
            if loadAttempts <= maxRetries {
                // Auto-retry with exponential backoff
                try? await Task.sleep(nanoseconds: UInt64(500_000_000 * loadAttempts))
                await loadAllData()
                return
            }
            
            errorMessage = "Couldn't load movie details. Tap to retry."
        }

        isLoading = false
    }

    // MARK: - Certification Loading

    private func loadCertificationSafely() async {
        do {
            let response = try await client.fetchReleaseDates(id: movie.id)
            
            // Try US first, then fall back to other English-speaking regions
            let regionsToTry = ["US", "GB", "CA", "AU"]
            
            for region in regionsToTry {
                if let cert = response.primaryCertification(forRegion: region), !cert.isEmpty {
                    self.certification = cert
                    break
                }
            }
            
            hasLoadedCertification = true
        } catch {
            print("⚠️ Certification load failed: \(error)")
            hasLoadedCertification = true // Mark as loaded even on failure
        }
    }

    // MARK: - Watch Providers Loading

    private func loadWatchProvidersSafely() async {
        do {
            let regionCode = currentRegionCode
            let response = try await client.fetchWatchProviders(id: movie.id)

            guard let region = response.region(regionCode) else {
                hasLoadedProviders = true
                return
            }

            // Separate by type for better UI organization
            self.streamingProviders = (region.flatrate ?? []).map {
                MovieWatchProvider(
                    id: $0.providerId,
                    name: $0.providerName,
                    logoPath: $0.logoPath,
                    type: .stream
                )
            }.sorted { $0.name < $1.name }
            
            self.rentProviders = (region.rent ?? []).map {
                MovieWatchProvider(
                    id: $0.providerId,
                    name: $0.providerName,
                    logoPath: $0.logoPath,
                    type: .rent
                )
            }.sorted { $0.name < $1.name }
            
            self.buyProviders = (region.buy ?? []).map {
                MovieWatchProvider(
                    id: $0.providerId,
                    name: $0.providerName,
                    logoPath: $0.logoPath,
                    type: .buy
                )
            }.sorted { $0.name < $1.name }

            self.watchProvidersRegion = regionCode
            hasLoadedProviders = true

        } catch {
            print("⚠️ Watch providers load failed: \(error)")
            hasLoadedProviders = true
        }
    }
    
    // MARK: - Recommendations Loading
    
    private func loadRecommendationsSafely() async {
        isLoadingRecommendations = true
        
        do {
            let response = try await client.fetchMovieRecommendations(id: movie.id, page: 1)
            
            // Filter out movies with no poster or very low ratings
            self.recommendations = response.results
                .filter { $0.posterPath != nil && $0.voteAverage > 4.0 }
                .prefix(12)
                .map { $0 }
            
        } catch {
            print("⚠️ Recommendations load failed: \(error)")
            // Not critical - UI can fall back to local recommendations
        }
        
        isLoadingRecommendations = false
    }
    
    // MARK: - Region Detection
    
    private var currentRegionCode: String {
        // Use device locale, fall back to US
        Locale.current.region?.identifier ?? "US"
    }

    // MARK: - Computed Display Properties

    var displayTitle: String {
        let detailTitle = detail?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !detailTitle.isEmpty {
            return detailTitle
        }
        return movie.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayYearText: String {
        guard let year = releaseYear else { return "—" }
        return String(year)
    }
    
    var releaseYear: Int? {
        let sourceDate = detail?.releaseDate ?? movie.releaseDate
        guard let date = sourceDate, date.count >= 4 else { return nil }
        return Int(date.prefix(4))
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
    
    var formattedVoteCount: String {
        let count = displayVoteCount
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    var headerImageURL: URL? {
        // Prefer backdrop for cinematic look
        if let d = detail {
            if let url = d.backdropURL { return url }
            if let url = d.posterURL { return url }
        }
        if let url = movie.backdropURL { return url }
        if let url = movie.posterURL { return url }
        return nil
    }
    
    var posterURL: URL? {
        detail?.posterURL ?? movie.posterURL
    }

    var overviewText: String? {
        let text = detail?.overview ?? movie.overview
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    var isOverviewLong: Bool {
        (overviewText?.count ?? 0) > 200
    }

    var runtimeText: String? {
        guard let runtime = detail?.runtime, runtime > 0 else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    var runtimeMinutes: Int? {
        detail?.runtime
    }

    var whereToWatchURL: URL? {
        URL(string: "https://www.themoviedb.org/movie/\(movie.id)/watch")
    }
    
    var tmdbURL: URL? {
        URL(string: "https://www.themoviedb.org/movie/\(movie.id)")
    }
    
    // Combined providers for simple display
    var watchProviders: [MovieWatchProvider] {
        // Prioritize streaming, then rent, then buy
        var combined: [MovieWatchProvider] = []
        var seenIDs = Set<Int>()
        
        for provider in streamingProviders {
            if !seenIDs.contains(provider.id) {
                combined.append(provider)
                seenIDs.insert(provider.id)
            }
        }
        for provider in rentProviders {
            if !seenIDs.contains(provider.id) {
                combined.append(provider)
                seenIDs.insert(provider.id)
            }
        }
        for provider in buyProviders {
            if !seenIDs.contains(provider.id) {
                combined.append(provider)
                seenIDs.insert(provider.id)
            }
        }
        
        return combined
    }
    
    var hasStreamingOptions: Bool {
        !streamingProviders.isEmpty
    }

    // MARK: - Smart Match Score

    var smartMatchScore: Int {
        var score: Double = 0
        
        let rating = displayVoteAverage
        let votes = Double(displayVoteCount)
        let year = releaseYear
        
        // Rating contribution (0-60 points)
        // Use logarithmic scale to differentiate high ratings more
        if rating > 0 {
            let normalizedRating = rating / 10.0
            score += pow(normalizedRating, 1.5) * 60.0
        }
        
        // Vote confidence (0-25 points)
        // More votes = more reliable score
        if votes > 50000 {
            score += 25
        } else if votes > 20000 {
            score += 20
        } else if votes > 5000 {
            score += 15
        } else if votes > 1000 {
            score += 10
        } else if votes > 200 {
            score += 5
        }
        
        // Recency bonus (0-15 points)
        if let y = year {
            let currentYear = Calendar.current.component(.year, from: Date())
            let age = max(0, currentYear - y)
            
            if age == 0 {
                score += 15  // Brand new
            } else if age <= 2 {
                score += 12
            } else if age <= 5 {
                score += 8
            } else if age <= 10 {
                score += 4
            }
            // Older movies get no recency bonus but aren't penalized
        }
        
        // Clamp to 10-98 range
        return max(10, min(98, Int(score.rounded())))
    }
    
    var smartMatchTier: MatchTier {
        let score = smartMatchScore
        if score >= 85 { return .excellent }
        if score >= 70 { return .great }
        if score >= 55 { return .good }
        return .fair
    }
    
    enum MatchTier {
        case excellent, great, good, fair
        
        var label: String {
            switch self {
            case .excellent: return "Excellent Match"
            case .great: return "Great Match"
            case .good: return "Good Match"
            case .fair: return "Fair Match"
            }
        }
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .great: return .blue
            case .good: return .orange
            case .fair: return .secondary
            }
        }
    }

    // MARK: - Smart Match Reasons

    var smartReasonLines: [String] {
        var reasons: [String] = []
        
        let rating = displayVoteAverage
        let votes = displayVoteCount
        
        // Rating-based reasons
        if rating >= 8.5 {
            reasons.append("Exceptional rating — one of the best in its category")
        } else if rating >= 8.0 {
            reasons.append("Critically acclaimed with outstanding audience scores")
        } else if rating >= 7.5 {
            reasons.append("Strong ratings well above the average film")
        } else if rating >= 7.0 {
            reasons.append("Solid ratings from audiences")
        }
        
        // Vote confidence reasons
        if votes > 50000 {
            reasons.append("Extremely well-reviewed with \(formattedVoteCount) ratings")
        } else if votes > 20000 {
            reasons.append("Highly trusted score from \(formattedVoteCount) viewers")
        } else if votes > 5000 {
            reasons.append("Well-established with thousands of reviews")
        } else if votes > 1000 {
            reasons.append("Solid review count for confidence in the score")
        } else if votes < 500 && votes > 0 {
            reasons.append("Newer or niche title — score may shift as more people watch")
        }
        
        // Recency reasons
        if let year = releaseYear {
            let currentYear = Calendar.current.component(.year, from: Date())
            let age = max(0, currentYear - year)
            
            if age == 0 {
                reasons.append("Brand new release — fresh for your watchlist")
            } else if age == 1 {
                reasons.append("Recent release still generating buzz")
            } else if age <= 3 {
                reasons.append("Modern pick that still feels current")
            } else if age >= 30 {
                reasons.append("Classic title with enduring appeal")
            } else if age >= 20 {
                reasons.append("Older gem that's stood the test of time")
            }
        }
        
        // Runtime reason
        if let runtime = runtimeMinutes {
            if runtime >= 180 {
                reasons.append("Epic length — plan for a long watch session")
            } else if runtime <= 90 {
                reasons.append("Quick watch — easy to fit into a busy evening")
            }
        }
        
        // Streaming availability reason
        if hasStreamingOptions {
            reasons.append("Available to stream now — no extra cost to watch")
        }
        
        // Fallback
        if reasons.isEmpty {
            reasons.append("Balanced mix of quality indicators")
        }
        
        return reasons
    }

    // MARK: - Quick Insights

    private static let genreNameByID: [Int: String] = [
        28: "Action", 12: "Adventure", 16: "Animation", 35: "Comedy",
        80: "Crime", 99: "Documentary", 18: "Drama", 10751: "Family",
        14: "Fantasy", 27: "Horror", 10402: "Music", 9648: "Mystery",
        10749: "Romance", 878: "Sci-Fi", 10770: "TV Movie", 53: "Thriller",
        10752: "War", 37: "Western", 36: "History"
    ]
    
    private var genreIDs: Set<Int> {
        if let d = detail {
            return Set(d.genres.map { $0.id })
        }
        return Set(movie.genreIDs ?? [])
    }
    
    private func hasGenre(_ id: Int) -> Bool {
        genreIDs.contains(id)
    }

    var quickInsights: [String] {
        var insights: [String] = []
        
        // Genre-based mood insights
        if hasGenre(27) { // Horror
            insights.append("🎃 Perfect for a spooky night")
        }
        
        if hasGenre(35) && hasGenre(10749) { // Comedy + Romance
            insights.append("💕 Great date night pick")
        } else if hasGenre(10749) { // Romance
            insights.append("❤️ Romantic mood setter")
        } else if hasGenre(35) { // Comedy
            insights.append("😄 Light and fun watch")
        }
        
        if hasGenre(28) || hasGenre(12) { // Action or Adventure
            insights.append("🎬 High-energy entertainment")
        }
        
        if hasGenre(53) { // Thriller
            insights.append("😰 Edge-of-your-seat tension")
        }
        
        if hasGenre(18) && !hasGenre(35) { // Drama (not comedy-drama)
            insights.append("🎭 Emotionally engaging story")
        }
        
        if hasGenre(878) { // Sci-Fi
            insights.append("🚀 Sci-fi adventure")
        }
        
        if hasGenre(16) { // Animation
            if hasGenre(10751) { // Family
                insights.append("👨‍👩‍👧 Great for family movie night")
            } else {
                insights.append("✨ Animated feature")
            }
        } else if hasGenre(10751) { // Family (non-animated)
            insights.append("👨‍👩‍👧 Family-friendly choice")
        }
        
        if hasGenre(99) { // Documentary
            insights.append("📚 Learn something new")
        }
        
        if hasGenre(9648) { // Mystery
            insights.append("🔍 Intriguing mystery")
        }
        
        if hasGenre(14) { // Fantasy
            insights.append("🧙 Fantastical world")
        }
        
        if hasGenre(10752) { // War
            insights.append("⚔️ War drama")
        }
        
        if hasGenre(37) { // Western
            insights.append("🤠 Western adventure")
        }
        
        // Rating-based insights
        if displayVoteAverage >= 8.5 {
            insights.append("⭐ Top-tier rating")
        }
        
        // Runtime insights
        if let runtime = runtimeMinutes {
            if runtime >= 150 {
                insights.append("⏱️ Epic runtime (\(runtimeText ?? ""))")
            } else if runtime <= 95 {
                insights.append("⚡ Quick watch (\(runtimeText ?? ""))")
            }
        }
        
        // Certification insights
        if let cert = certification {
            switch cert {
            case "G":
                insights.append("👶 All ages welcome")
            case "PG":
                insights.append("🧒 Suitable for kids with guidance")
            case "PG-13":
                insights.append("🔞 Teen-appropriate")
            case "R", "NC-17":
                insights.append("🔞 Mature audiences only")
            default:
                break
            }
        }
        
        // De-duplicate and limit
        var seen = Set<String>()
        return insights.filter { insight in
            if seen.contains(insight) { return false }
            seen.insert(insight)
            return true
        }.prefix(6).map { $0 }
    }
    
    // MARK: - Watch Context Suggestions
    
    var watchContexts: [WatchContext] {
        var contexts: [WatchContext] = []
        
        // Date night
        if hasGenre(10749) || (hasGenre(35) && hasGenre(18)) {
            contexts.append(.dateNight)
        }
        
        // Family
        if hasGenre(10751) || hasGenre(16) {
            contexts.append(.familyNight)
        }
        
        // Solo chill
        if hasGenre(99) || hasGenre(18) {
            contexts.append(.soloWatch)
        }
        
        // Friends
        if hasGenre(35) || hasGenre(28) || hasGenre(27) {
            contexts.append(.friendsNight)
        }
        
        // Background
        if let runtime = runtimeMinutes, runtime <= 100, hasGenre(35) {
            contexts.append(.background)
        }
        
        return Array(contexts.prefix(3))
    }
    
    enum WatchContext: String, CaseIterable {
        case dateNight = "Date Night"
        case familyNight = "Family Night"
        case soloWatch = "Solo Watch"
        case friendsNight = "With Friends"
        case background = "Background Watch"
        
        var icon: String {
            switch self {
            case .dateNight: return "heart.fill"
            case .familyNight: return "figure.2.and.child.holdinghands"
            case .soloWatch: return "person.fill"
            case .friendsNight: return "person.3.fill"
            case .background: return "tv"
            }
        }
    }
    
    // MARK: - Share Text
    
    var shareText: String {
        var text = "Check out \(displayTitle)"
        if let year = releaseYear {
            text += " (\(year))"
        }
        text += " — rated \(String(format: "%.1f", displayVoteAverage))/10"
        if let url = tmdbURL {
            text += "\n\(url.absoluteString)"
        }
        return text
    }
}
