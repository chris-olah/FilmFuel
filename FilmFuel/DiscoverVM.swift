//
//  DiscoverVM.swift
//  FilmFuel
//
//  STREAMLINED: Keeps essential discovery features, removes excessive gamification
//  Focus: Great movie discovery, natural premium value, clean data flow
//

import Foundation
import SwiftUI
import Combine

// MARK: - Persistence Stores

private enum FavoriteStore {
    private static let key = "ff.discover.favorites.tmdb"
    static func load() -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
    }
    static func save(_ set: Set<Int>) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

private enum SeenStore {
    private static let key = "ff.discover.seen.tmdb"
    static func load() -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
    }
    static func save(_ set: Set<Int>) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

// MARK: - WatchlistStore (persists full movie objects)

private enum WatchlistStore {
    private static let idsKey    = "ff.discover.watchlist.tmdb"
    private static let moviesKey = "ff.discover.watchlist.movies"

    static func loadIDs() -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: idsKey) as? [Int] ?? [])
    }

    static func loadMovies() -> [TMDBMovie] {
        guard let data = UserDefaults.standard.data(forKey: moviesKey),
              let movies = try? JSONDecoder().decode([TMDBMovie].self, from: data)
        else { return [] }
        return movies
    }

    static func save(ids: Set<Int>, movies: [TMDBMovie]) {
        UserDefaults.standard.set(Array(ids), forKey: idsKey)
        if let data = try? JSONEncoder().encode(movies) {
            UserDefaults.standard.set(data, forKey: moviesKey)
        }
    }
}

private enum DislikedStore {
    private static let key = "ff.discover.disliked.tmdb"
    static func load() -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
    }
    static func save(_ set: Set<Int>) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

private enum RandomSeenStore {
    private static let key = "ff.discover.randomSeen.tmdb"
    static func load() -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
    }
    static func save(_ set: Set<Int>) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

// MARK: - Movie Mood

enum MovieMood: String, CaseIterable, Identifiable {
    case any, cozy, adrenaline, dateNight, nostalgic, feelGood, mindBend, spooky
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .any:        return "Any Mood"
        case .cozy:       return "Cozy"
        case .adrenaline: return "Adrenaline"
        case .dateNight:  return "Date Night"
        case .nostalgic:  return "Nostalgic"
        case .feelGood:   return "Feel-Good"
        case .mindBend:   return "Mind-Bend"
        case .spooky:     return "Spooky"
        }
    }
    
    var emoji: String {
        switch self {
        case .any:        return "🎬"
        case .cozy:       return "🛋️"
        case .adrenaline: return "⚡"
        case .dateNight:  return "💕"
        case .nostalgic:  return "📼"
        case .feelGood:   return "☀️"
        case .mindBend:   return "🧠"
        case .spooky:     return "👻"
        }
    }
    
    func matches(movie: TMDBMovie) -> Bool {
        if self == .any { return true }
        
        var year: Int? = nil
        if let release = movie.releaseDate, let y = Int(release.prefix(4)) {
            year = y
        }
        
        let ids = Set(movie.genreIDs ?? [])
        func has(_ g: Int) -> Bool { ids.contains(g) }
        
        switch self {
        case .any:        return true
        case .cozy:       return has(10751) || has(16) || has(35) || has(10749)
        case .adrenaline: return has(28) || has(12) || has(53)
        case .dateNight:  return has(10749) || has(35)
        case .nostalgic:  return year.map { $0 < 2008 } ?? false
        case .feelGood:   return has(35) || has(10751) || has(14)
        case .mindBend:   return has(878) || has(9648)
        case .spooky:     return has(27)
        }
    }
}

// MARK: - Taste Profile

// MARK: - User Level (Kept for compatibility with StatsView, SmartMixManager)

enum UserLevel: Int, CaseIterable {
    case newbie = 0
    case explorer = 1
    case enthusiast = 2
    case cinephile = 3
    case connoisseur = 4
    case elite = 5
    
    var title: String {
        switch self {
        case .newbie:      return "Film Newbie"
        case .explorer:    return "Explorer"
        case .enthusiast:  return "Enthusiast"
        case .cinephile:   return "Cinephile"
        case .connoisseur: return "Connoisseur"
        case .elite:       return "Elite Curator"
        }
    }
    
    var icon: String {
        switch self {
        case .newbie:      return "person.fill"
        case .explorer:    return "binoculars.fill"
        case .enthusiast:  return "star.fill"
        case .cinephile:   return "film.fill"
        case .connoisseur: return "crown.fill"
        case .elite:       return "sparkles"
        }
    }
    
    var requiredXP: Int {
        switch self {
        case .newbie:      return 0
        case .explorer:    return 50
        case .enthusiast:  return 150
        case .cinephile:   return 400
        case .connoisseur: return 1000
        case .elite:       return 2500
        }
    }
    
    static func level(for xp: Int) -> UserLevel {
        for level in Self.allCases.reversed() {
            if xp >= level.requiredXP {
                return level
            }
        }
        return .newbie
    }
    
    var next: UserLevel? {
        UserLevel(rawValue: rawValue + 1)
    }
}

struct TasteProfile {
    private(set) var genreCounts: [Int: Int] = [:]
    private(set) var decadeCounts: [Int: Int] = [:]
    
    var tasteStrength: Double {
        let total = genreCounts.values.reduce(0, +)
        return min(1.0, Double(total) / 50.0)
    }
    
    mutating func record(genreIDs: [Int]) {
        for g in genreIDs {
            genreCounts[g, default: 0] += 1
        }
    }
    
    mutating func recordDecade(from movie: TMDBMovie, multiplier: Int = 1) {
        guard let dateString = movie.releaseDate,
              let year = Int(dateString.prefix(4)),
              year > 1900 else { return }
        
        let decade = (year / 10) * 10
        guard decade > 1900 else { return }
        
        for _ in 0..<multiplier {
            decadeCounts[decade, default: 0] += 1
        }
    }
    
    var topGenreIDs: [Int] {
        Array(genreCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key })
    }
    
    var favoriteDecade: Int? {
        decadeCounts.max(by: { $0.value < $1.value })?.key
    }
    
    func score(for movie: TMDBMovie) -> Int {
        let favs = Set(topGenreIDs)
        let movieGenres = Set(movie.genreIDs ?? [])
        return favs.intersection(movieGenres).count
    }
    
    /// Smart Match percentage for premium users
    func matchPercentage(for movie: TMDBMovie) -> Int {
        guard !topGenreIDs.isEmpty else { return Int.random(in: 72...89) }
        
        let movieGenres = Set(movie.genreIDs ?? [])
        let overlap = Set(topGenreIDs).intersection(movieGenres).count
        let base = 65 + (overlap * 12)
        let bonus = movie.voteAverage >= 7.5 ? 8 : 0
        return min(99, base + bonus + Int.random(in: 0...5))
    }
}

// MARK: - ViewModel

@MainActor
final class DiscoverVM: ObservableObject {
    
    // MARK: - Mode
    
    enum Mode: String, CaseIterable, Identifiable {
        case forYou, trending, popular, hiddenGems
        
        var id: String { rawValue }
        
        var label: String {
            switch self {
            case .forYou:     return "For You"
            case .trending:   return "Trending"
            case .popular:    return "Popular"
            case .hiddenGems: return "Hidden Gems"
            }
        }
        
        var icon: String {
            switch self {
            case .forYou:     return "sparkles"
            case .trending:   return "flame.fill"
            case .popular:    return "star.fill"
            case .hiddenGems: return "diamond.fill"
            }
        }
        
        var isPremium: Bool {
            self == .hiddenGems
        }
    }
    
    // MARK: - Genre Mapping
    
    static let genreNameByID: [Int: String] = [
        28: "Action", 12: "Adventure", 16: "Animation", 35: "Comedy",
        80: "Crime", 99: "Documentary", 18: "Drama", 10751: "Family",
        14: "Fantasy", 27: "Horror", 10402: "Music", 9648: "Mystery",
        10749: "Romance", 878: "Sci-Fi", 10770: "TV Movie", 53: "Thriller",
        10752: "War", 37: "Western"
    ]
    
    // MARK: - Published State
    
    @Published private(set) var movies: [TMDBMovie] = []
    @Published var filters: DiscoverFilters = .default
    @Published var selectedMood: MovieMood = .any
    @Published var useSmartMode: Bool = true
    @Published var tasteProfile = TasteProfile()
    
    // User collections
    @Published var favorites: Set<Int> = FavoriteStore.load() {
        didSet { FavoriteStore.save(favorites) }
    }
    @Published var seenMovieIDs: Set<Int> = SeenStore.load() {
        didSet { SeenStore.save(seenMovieIDs) }
    }

    // Watchlist: IDs for fast lookup + full objects for display
    @Published var watchlistMovieIDs: Set<Int> = WatchlistStore.loadIDs()
    @Published var watchlistMovies: [TMDBMovie] = WatchlistStore.loadMovies()

    @Published var dislikedMovieIDs: Set<Int> = DislikedStore.load() {
        didSet { DislikedStore.save(dislikedMovieIDs) }
    }
    
    // Mode & loading
    @Published var mode: Mode = .forYou {
        didSet { Task { await reloadForMode() } }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchQuery: String = "" {
        didSet { Task { await handleSearchChange() } }
    }
    
    // Pagination
    @Published private(set) var currentPage: Int = 1
    @Published private(set) var hasMorePages: Bool = true
    
    // MARK: - Computed Properties
    
    var displayedMovies: [TMDBMovie] {
        var result = movies
        
        // Apply filters
        if filters.onlyFavorites {
            result = result.filter { favorites.contains($0.id) }
        }
        
        if filters.minRating > 0 {
            result = result.filter { $0.voteAverage >= filters.minRating }
        }
        
        if filters.minYear != nil || filters.maxYear != nil {
            result = result.filter { movie in
                guard let dateString = movie.releaseDate,
                      let year = Int(dateString.prefix(4)) else { return false }
                if let minY = filters.minYear, year < minY { return false }
                if let maxY = filters.maxYear, year > maxY { return false }
                return true
            }
        }
        
        if !filters.selectedGenreIDs.isEmpty {
            result = result.filter { movie in
                guard let ids = movie.genreIDs, !ids.isEmpty else { return false }
                return !filters.selectedGenreIDs.isDisjoint(with: Set(ids))
            }
        }
        
        // Apply mood filter
        if selectedMood != .any {
            result = result.filter { selectedMood.matches(movie: $0) }
        }
        
        // Remove disliked
        if !dislikedMovieIDs.isEmpty {
            result = result.filter { !dislikedMovieIDs.contains($0.id) }
        }
        
        // Smart sort for "For You" mode
        if useSmartMode, !tasteProfile.topGenreIDs.isEmpty, mode == .forYou, !isSearching {
            result = result.sorted { tasteProfile.score(for: $0) > tasteProfile.score(for: $1) }
        }
        
        // Hide already seen in For You
        if mode == .forYou, !isSearching {
            result = result.filter { !seenMovieIDs.contains($0.id) }
        }
        
        return result
    }
    
    var topGenreNames: [String] {
        tasteProfile.topGenreIDs.compactMap { Self.genreNameByID[$0] }
    }
    
    var favoriteDecadeLabel: String? {
        guard let decade = tasteProfile.favoriteDecade else { return nil }
        return decade >= 2000 ? "\(decade)s" : "\(decade % 100)s"
    }
    
    // MARK: - Private State
    
    private let client: TMDBClientProtocol
    @Published private(set) var isSearching: Bool = false
    private let randomPagesToLoad = 5
    private let maxRandomMovies = 40
    private var sessionSeenRandomMovieIDs: Set<Int> = []
    private var lifetimeSeenRandomMovieIDs: Set<Int> = RandomSeenStore.load()
    private let maxLifetimeSeenCount = 600
    private let randomBaseSeed: Int
    private var randomReloadCount: Int = 0
    
    // MARK: - Init
    
    init(client: TMDBClientProtocol = TMDBClient()) {
        self.client = client
        self.randomBaseSeed = Int.random(in: 0...999_999)
    }
    
    // MARK: - Public API
    
    func loadInitial() {
        Task { await reloadForMode() }
    }
    
    func loadNextPage() {
        guard !isLoading, hasMorePages else { return }
        Task {
            await loadMore()
        }
    }
    
    func clearFilters() {
        filters = .default
        selectedMood = .any
        loadInitial()
    }
    
    // MARK: - Movie Actions
    
    func toggleFavorite(_ movie: TMDBMovie) {
        if favorites.contains(movie.id) {
            favorites.remove(movie.id)
        } else {
            favorites.insert(movie.id)
            if let ids = movie.genreIDs {
                tasteProfile.record(genreIDs: ids)
            }
            tasteProfile.recordDecade(from: movie)
            StatsManager.shared.trackMovieFavorited()
        }
    }
    
    func isFavorite(_ movie: TMDBMovie) -> Bool {
        favorites.contains(movie.id)
    }
    
    // MARK: - Watchlist (stores full movie objects)

    func toggleWatchlist(_ movie: TMDBMovie) {
        if watchlistMovieIDs.contains(movie.id) {
            watchlistMovieIDs.remove(movie.id)
            watchlistMovies.removeAll { $0.id == movie.id }
        } else {
            watchlistMovieIDs.insert(movie.id)
            watchlistMovies.insert(movie, at: 0)
        }
        WatchlistStore.save(ids: watchlistMovieIDs, movies: watchlistMovies)
    }
    
    func isInWatchlist(_ movie: TMDBMovie) -> Bool {
        watchlistMovieIDs.contains(movie.id)
    }

    func removeFromWatchlist(_ movie: TMDBMovie) {
        watchlistMovieIDs.remove(movie.id)
        watchlistMovies.removeAll { $0.id == movie.id }
        WatchlistStore.save(ids: watchlistMovieIDs, movies: watchlistMovies)
    }
    
    func toggleSeen(_ movie: TMDBMovie) {
        if seenMovieIDs.contains(movie.id) {
            seenMovieIDs.remove(movie.id)
        } else {
            seenMovieIDs.insert(movie.id)
            if let ids = movie.genreIDs {
                tasteProfile.record(genreIDs: ids)
            }
            tasteProfile.recordDecade(from: movie)
        }
    }
    
    func isSeen(_ movie: TMDBMovie) -> Bool {
        seenMovieIDs.contains(movie.id)
    }
    
    func toggleDisliked(_ movie: TMDBMovie) {
        if dislikedMovieIDs.contains(movie.id) {
            dislikedMovieIDs.remove(movie.id)
        } else {
            dislikedMovieIDs.insert(movie.id)
            favorites.remove(movie.id)
            watchlistMovieIDs.remove(movie.id)
            watchlistMovies.removeAll { $0.id == movie.id }
            WatchlistStore.save(ids: watchlistMovieIDs, movies: watchlistMovies)
        }
    }
    
    func isDisliked(_ movie: TMDBMovie) -> Bool {
        dislikedMovieIDs.contains(movie.id)
    }
    
    // MARK: - Mode & Mood Selection
    
    func userSelectedMode(_ newMode: Mode) {
        // Note: Premium check handled in View
        mode = newMode
    }
    
    func userSelectedMood(_ mood: MovieMood) {
        selectedMood = mood
    }
    
    func recordDetailOpen(_ movie: TMDBMovie) {
        if let ids = movie.genreIDs {
            tasteProfile.record(genreIDs: ids)
        }
        tasteProfile.recordDecade(from: movie)
    }
    
    // MARK: - Smart Match (Premium Feature)
    
    func matchPercentage(for movie: TMDBMovie) -> Int {
        tasteProfile.matchPercentage(for: movie)
    }
    
    func briefReasonFor(_ movie: TMDBMovie) -> String? {
        guard mode == .forYou, useSmartMode else { return nil }
        
        if selectedMood.matches(movie: movie) {
            return "Matches your \(selectedMood.label.lowercased()) mood"
        }

        
        let favGenreIDs = Set(tasteProfile.topGenreIDs)
        if !favGenreIDs.isEmpty, let movieIDs = movie.genreIDs {
            let overlapIDs = favGenreIDs.intersection(movieIDs)
            if let first = overlapIDs.first, let name = Self.genreNameByID[first] {
                return "Because you love \(name.lowercased())"
            }
        }
        
        if movie.voteAverage >= 8.0, movie.voteCount >= 2000 {
            return "Highly rated by \(movie.voteCount.formatted()) viewers"
        }
        
        return nil
    }
    
    func trainTaste(on movie: TMDBMovie, isStrong: Bool) {
        guard let ids = movie.genreIDs, !ids.isEmpty else { return }
        
        let multiplier = isStrong ? 4 : 1
        for _ in 0..<multiplier {
            tasteProfile.record(genreIDs: ids)
            tasteProfile.recordDecade(from: movie)
        }
        
        if isStrong {
            useSmartMode = true
        }
    }
    
    // MARK: - Data Loading
    
    private func reloadForMode() async {
        currentPage = 1
        hasMorePages = true
        
        isSearching = false
        isLoading = true
        errorMessage = nil
        
        do {
            if filters.isActive {
                try await loadFilteredMoviesForCurrentMode()
            } else {
                switch mode {
                case .forYou:     try await loadRandomMovies()
                case .trending:   try await loadTrendingMovies()
                case .popular:    try await loadPopularMovies()
                case .hiddenGems: try await loadHiddenGems()
                }
            }
        } catch {
            errorMessage = "Could not load movies. Please try again."
            print("TMDB error: \(error)")
        }
        
        isLoading = false
    }
    
    private func loadMore() async {
        guard !isLoading else { return }
        
        currentPage += 1
        isLoading = true
        
        do {
            let response: TMDBMovieListResponse
            
            switch mode {
            case .forYou, .hiddenGems:
                response = try await client.fetchDiscoverMovies(page: currentPage, sortBy: "popularity.desc")
            case .trending:
                response = try await client.fetchTrendingMovies(page: currentPage)
            case .popular:
                response = try await client.fetchPopularMovies(page: currentPage)
            }
            
            let newMovies = response.results.filter { $0.posterPath != nil && $0.voteCount >= 20 }
            movies.append(contentsOf: newMovies)
            hasMorePages = currentPage < response.totalPages
            
        } catch {
            print("Load more error: \(error)")
            currentPage -= 1
        }
        
        isLoading = false
    }
    
    private func loadFilteredMoviesForCurrentMode() async throws {
        let sortBy = filters.sort.tmdbSortKey
        
        let providerIDs: [Int]? = filters.selectedStreamingServices.isEmpty
            ? nil
            : filters.selectedStreamingServices.map { $0.providerID }
        
        let preset = filters.runtimePreset
        let runtimeMin: Int? = preset == .any ? nil : filters.customMinRuntime
        let runtimeMax: Int? = preset == .any ? nil : filters.customMaxRuntime
        
        let actorName = filters.actorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let directorName = filters.directorName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var actorID: Int? = nil
        var directorID: Int? = nil
        
        if !actorName.isEmpty {
            actorID = try? await client.searchPersonID(named: actorName, departmentHint: .acting)
        }
        
        if !directorName.isEmpty {
            directorID = try? await client.searchPersonID(named: directorName, departmentHint: .directing)
        }
        
        let params = TMDBDiscoverParams(
            sortBy: sortBy,
            minRating: filters.minRating > 0 ? filters.minRating : nil,
            minYear: filters.minYear,
            maxYear: filters.maxYear,
            genreIDs: filters.selectedGenreIDs.isEmpty ? nil : Array(filters.selectedGenreIDs),
            watchProviderIDs: providerIDs,
            watchRegion: "US",
            minRuntime: runtimeMin,
            maxRuntime: runtimeMax,
            actorPersonID: actorID,
            directorPersonID: directorID
        )
        
        if mode == .forYou {
            randomReloadCount += 1
        }
        
        let response = try await client.fetchFilteredDiscoverMovies(page: 1, params: params)
        
        var withImages = response.results.filter { $0.posterPath != nil && $0.voteCount >= 20 }
        
        if mode == .forYou {
            let currentSeed = randomBaseSeed &+ randomReloadCount
            var shuffleRNG = SeededGenerator(seed: currentSeed &+ 10_000)
            withImages.shuffle(using: &shuffleRNG)
            withImages = Array(withImages.prefix(maxRandomMovies))
        }
        
        movies = withImages
        hasMorePages = response.totalPages > 1
    }
    
    private func loadRandomMovies() async throws {
        randomReloadCount += 1
        let currentSeed = randomBaseSeed &+ randomReloadCount
        
        let firstDiscover = try await client.fetchDiscoverMovies(page: 1, sortBy: "popularity.desc")
        let totalPages = max(1, min(firstDiscover.totalPages, 500))
        var allResults: [TMDBMovie] = firstDiscover.results
        
        var excludedIDs = Set<Int>()
        if let trending = try? await client.fetchTrendingMovies(page: 1) {
            excludedIDs.formUnion(trending.results.map { $0.id })
        }
        if let popular = try? await client.fetchPopularMovies(page: 1) {
            excludedIDs.formUnion(popular.results.map { $0.id })
        }
        
        var pages = Set<Int>([1])
        var pageRNG = SeededGenerator(seed: currentSeed)
        
        while pages.count < randomPagesToLoad && pages.count < totalPages {
            pages.insert(Int.random(in: 1...totalPages, using: &pageRNG))
        }
        
        for page in pages where page != 1 {
            let resp = try await client.fetchDiscoverMovies(page: page, sortBy: "popularity.desc")
            allResults.append(contentsOf: resp.results)
        }
        
        var withImages = allResults.filter {
            $0.posterPath != nil && $0.voteCount >= 20 && !excludedIDs.contains($0.id)
        }
        
        var seenInBatch = Set<Int>()
        withImages.removeAll { movie in
            if seenInBatch.contains(movie.id) { return true }
            seenInBatch.insert(movie.id)
            return false
        }
        
        var unseen = withImages.filter {
            !sessionSeenRandomMovieIDs.contains($0.id) &&
            !lifetimeSeenRandomMovieIDs.contains($0.id)
        }
        
        if unseen.isEmpty {
            sessionSeenRandomMovieIDs = []
            lifetimeSeenRandomMovieIDs = []
            RandomSeenStore.save(lifetimeSeenRandomMovieIDs)
            unseen = withImages
        }
        
        var shuffleRNG = SeededGenerator(seed: currentSeed &+ 10_000)
        let feed = Array(unseen.shuffled(using: &shuffleRNG).prefix(maxRandomMovies))
        
        sessionSeenRandomMovieIDs.formUnion(feed.map { $0.id })
        lifetimeSeenRandomMovieIDs.formUnion(feed.map { $0.id })
        
        if lifetimeSeenRandomMovieIDs.count > maxLifetimeSeenCount {
            var rng = SeededGenerator(seed: currentSeed &+ 20_000)
            lifetimeSeenRandomMovieIDs = Set(Array(lifetimeSeenRandomMovieIDs).shuffled(using: &rng).prefix(maxLifetimeSeenCount))
        }
        
        RandomSeenStore.save(lifetimeSeenRandomMovieIDs)
        movies = feed
        hasMorePages = true
    }
    
    private func loadTrendingMovies() async throws {
        let response = try await client.fetchTrendingMovies(page: 1)
        movies = response.results.filter { $0.posterPath != nil && $0.voteCount >= 20 }
        hasMorePages = response.totalPages > 1
    }
    
    private func loadPopularMovies() async throws {
        let response = try await client.fetchPopularMovies(page: 1)
        movies = response.results.filter { $0.posterPath != nil && $0.voteCount >= 20 }
        hasMorePages = response.totalPages > 1
    }
    
    private func loadHiddenGems() async throws {
        let response = try await client.fetchDiscoverMovies(page: Int.random(in: 5...20), sortBy: "vote_average.desc")
        movies = response.results.filter {
            $0.posterPath != nil && $0.voteAverage >= 7.0 && $0.voteCount >= 50 && $0.voteCount <= 500
        }
        hasMorePages = false // Hidden gems is curated
    }
    
    private func handleSearchChange() async {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            isSearching = false
            await reloadForMode()
            return
        }
        
        isSearching = true
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await client.searchMovies(query: trimmed, page: 1)
            movies = response.results.filter { $0.posterPath != nil && $0.voteCount >= 20 }
            hasMorePages = response.totalPages > 1
        } catch {
            errorMessage = "Search failed. Please try again."
        }
        
        isLoading = false
    }
}

// MARK: - Seeded RNG

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed))
        if self.state == 0 { self.state = 0xdead_beef }
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}
