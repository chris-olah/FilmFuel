//
//  DiscoverVM.swift
//  FilmFuel
//

import Foundation
import SwiftUI
import Combine

// MARK: - Favorites Store (by TMDB movie id)

private enum FavoriteStore {
    private static let key = "ff.discover.favorites.tmdb"

    static func load() -> Set<Int> {
        if let array = UserDefaults.standard.array(forKey: key) as? [Int] {
            return Set(array)
        }
        return []
    }

    static func save(_ set: Set<Int>) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

// MARK: - Lifetime "seen in Random" store (for variety)

private enum RandomSeenStore {
    private static let key = "ff.discover.randomSeen.tmdb"

    static func load() -> Set<Int> {
        if let array = UserDefaults.standard.array(forKey: key) as? [Int] {
            return Set(array)
        }
        return []
    }

    static func save(_ set: Set<Int>) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

// MARK: - User preference stores (Seen / Watchlist / Disliked)

private enum SeenStore {
    private static let key = "ff.discover.seen.tmdb"

    static func load() -> Set<Int> {
        if let array = UserDefaults.standard.array(forKey: key) as? [Int] {
            return Set(array)
        }
        return []
    }

    static func save(_ set: Set<Int>) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

private enum WatchlistStore {
    private static let key = "ff.discover.watchlist.tmdb"

    static func load() -> Set<Int> {
        if let array = UserDefaults.standard.array(forKey: key) as? [Int] {
            return Set(array)
        }
        return []
    }

    static func save(_ set: Set<Int>) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

private enum DislikedStore {
    private static let key = "ff.discover.disliked.tmdb"

    static func load() -> Set<Int> {
        if let array = UserDefaults.standard.array(forKey: key) as? [Int] {
            return Set(array)
        }
        return []
    }

    static func save(_ set: Set<Int>) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

// MARK: - Movie Mood (for Discover 2.0)

enum MovieMood: String, CaseIterable, Identifiable {
    case any
    case cozy
    case adrenaline
    case dateNight
    case nostalgic
    case feelGood
    case mindBend
    case spooky

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

    func matches(movie: TMDBMovie) -> Bool {
        if self == .any { return true }

        // Parse year from releaseDate
        var year: Int? = nil
        if let release = movie.releaseDate, let y = Int(release.prefix(4)) {
            year = y
        }

        let ids = Set(movie.genreIDs ?? [])
        func has(_ g: Int) -> Bool { ids.contains(g) }

        switch self {
        case .cozy:
            return has(10751) || has(16) || has(35) || has(10749)
        case .adrenaline:
            return has(28) || has(12) || has(53)
        case .dateNight:
            return has(10749) || has(35)
        case .nostalgic:
            if let y = year {
                return y < 2008
            }
            return false
        case .feelGood:
            return has(35) || has(10751) || has(14)
        case .mindBend:
            return has(878) || has(9648)
        case .spooky:
            return has(27)
        case .any:
            return true
        }
    }
}

// MARK: - Taste Profile

struct TasteProfile {
    private(set) var genreCounts: [Int: Int] = [:]

    mutating func record(genreIDs: [Int]) {
        for g in genreIDs {
            genreCounts[g, default: 0] += 1
        }
    }

    var topGenreIDs: [Int] {
        let sorted = genreCounts.sorted { $0.value > $1.value }
        return Array(sorted.prefix(3)).map { $0.key }
    }

    func score(for movie: TMDBMovie) -> Int {
        let favs = Set(topGenreIDs)
        let movieGenres = Set(movie.genreIDs ?? [])
        return favs.intersection(movieGenres).count
    }
}

// MARK: - ViewModel

@MainActor
final class DiscoverVM: ObservableObject {

    enum Mode: String, CaseIterable, Identifiable {
        case random
        case trending
        case popular

        var id: String { rawValue }

        var label: String {
            switch self {
            case .random:   return "For You"
            case .trending: return "Trending"
            case .popular:  return "Popular"
            }
        }
    }

    enum RandomFlavor: String, CaseIterable, Identifiable {
        case pure
        case hotRightNow
        case criticallyAcclaimed
        case fromYourTaste

        var id: String { rawValue }

        var shortLabel: String {
            switch self {
            case .pure:                return "Pure random"
            case .hotRightNow:         return "Hot right now"
            case .criticallyAcclaimed: return "Critically acclaimed"
            case .fromYourTaste:       return "From your taste"
            }
        }

        var subtitle: String {
            switch self {
            case .pure:
                return "Anything with good buzz"
            case .hotRightNow:
                return "High rating & lots of votes"
            case .criticallyAcclaimed:
                return "Only top-rated picks"
            case .fromYourTaste:
                return "Leans into your favorites"
            }
        }
    }

    // MARK: - Static genre mapping for taste names

    static let genreNameByID: [Int: String] = [
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

    // Base loaded movies (random / trending / popular / search / filtered discover)
    @Published private(set) var movies: [TMDBMovie] = []

    // Filters
    @Published var filters: DiscoverFilters = .default

    // Discover 2.0 additions
    @Published var selectedMood: MovieMood = .any
    @Published var useSmartMode: Bool = true
    @Published var tasteProfile = TasteProfile()
    @Published var randomFlavor: RandomFlavor = .pure

    // Tip nudges
    @Published var showTipNudge: Bool = false
    @Published var tipNudgeMessage: String?

    // User preference state
    @Published var favorites: Set<Int> = FavoriteStore.load() {
        didSet { FavoriteStore.save(favorites) }
    }

    @Published var seenMovieIDs: Set<Int> = SeenStore.load() {
        didSet { SeenStore.save(seenMovieIDs) }
    }

    @Published var watchlistMovieIDs: Set<Int> = WatchlistStore.load() {
        didSet { WatchlistStore.save(watchlistMovieIDs) }
    }

    @Published var dislikedMovieIDs: Set<Int> = DislikedStore.load() {
        didSet { DislikedStore.save(dislikedMovieIDs) }
    }

    // Movies after applying filters locally (favorites, mood, sanity, user prefs)
    var displayedMovies: [TMDBMovie] {
        var result = movies

        // Favorites only
        if filters.onlyFavorites {
            result = result.filter { favorites.contains($0.id) }
        }

        // Minimum rating (0–10)
        if filters.minRating > 0 {
            result = result.filter { movie in
                movie.voteAverage >= filters.minRating
            }
        }

        // Year range from releaseDate "YYYY-MM-DD"
        if filters.minYear != nil || filters.maxYear != nil {
            result = result.filter { movie in
                guard
                    let dateString = movie.releaseDate,
                    let year = Int(dateString.prefix(4))
                else {
                    return false
                }

                if let minY = filters.minYear, year < minY { return false }
                if let maxY = filters.maxYear, year > maxY { return false }
                return true
            }
        }

        // Genres: require at least one overlap between movie.genreIDs and selectedGenreIDs
        if !filters.selectedGenreIDs.isEmpty {
            result = result.filter { movie in
                guard let ids = movie.genreIDs, !ids.isEmpty else {
                    return false
                }
                let movieSet = Set(ids)
                return !filters.selectedGenreIDs.isDisjoint(with: movieSet)
            }
        }

        // Mood filter (on top of everything else)
        if selectedMood != .any {
            result = result.filter { selectedMood.matches(movie: $0) }
        }

        // Filter out "Not for me" / disliked movies globally
        if !dislikedMovieIDs.isEmpty {
            result = result.filter { !dislikedMovieIDs.contains($0.id) }
        }

        // Smart taste-based weighting, only in random mode & not during search
        if useSmartMode,
           !tasteProfile.topGenreIDs.isEmpty,
           mode == .random,
           !isSearching {
            result = result.sorted {
                tasteProfile.score(for: $0) > tasteProfile.score(for: $1)
            }
        }

        // In Random / For You, don't show things user marked as "Seen it"
        if mode == .random, !isSearching {
            result = result.filter { !seenMovieIDs.contains($0.id) }
        }

        return result
    }

    @Published var mode: Mode = .random {
        didSet {
            Task { [weak self] in
                await self?.reloadForMode()
            }
        }
    }

    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var searchQuery: String = "" {
        didSet {
            Task { [weak self] in
                await self?.handleSearchChange()
            }
        }
    }

    var topGenreNames: [String] {
        tasteProfile.topGenreIDs.compactMap { Self.genreNameByID[$0] }
    }

    private let client: TMDBClientProtocol
    fileprivate var isSearching: Bool = false

    // How many random pages to sample in Random mode (unfiltered)
    private let randomPagesToLoad = 5
    // How many movies to surface in a random feed
    private let maxRandomMovies = 40

    // Track which movie IDs we've already shown in Random mode this session
    private var sessionSeenRandomMovieIDs: Set<Int> = []

    // Lifetime history of seen IDs across launches
    private var lifetimeSeenRandomMovieIDs: Set<Int> = RandomSeenStore.load()
    private let maxLifetimeSeenCount = 600

    // Seeded randomness so "Random" feels random but not glitchy
    private let randomBaseSeed: Int
    private var randomReloadCount: Int = 0

    // Tip nudge counts
    private var shuffleCount: Int = 0
    private var detailOpenCount: Int = 0

    init(client: TMDBClientProtocol) {
        self.client = client
        // Base seed for this VM lifetime (stable with @StateObject)
        self.randomBaseSeed = Int.random(in: 0...999_999)
    }

    // MARK: - Public

    func loadInitial() {
        Task { [weak self] in
            await self?.reloadForMode()
        }
    }

    /// Shuffle for Random mode (user tapped “Shuffle”), separate from initial load
    func shuffleRandomFeed() {
        guard mode == .random else {
            // If not in random mode, just reload mode feed
            loadInitial()
            return
        }

        shuffleCount &+= 1

        Task { [weak self] in
            await self?.reloadForMode()
            self?.maybeShowTipNudge(reason: .shuffle)
        }
    }

    func toggleFavorite(_ movie: TMDBMovie) {
        if favorites.contains(movie.id) {
            favorites.remove(movie.id)
        } else {
            favorites.insert(movie.id)
            if let ids = movie.genreIDs {
                tasteProfile.record(genreIDs: ids)
            }
        }
    }

    func isFavorite(_ movie: TMDBMovie) -> Bool {
        favorites.contains(movie.id)
    }

    // MARK: - Watchlist / Seen / Disliked

    func toggleWatchlist(_ movie: TMDBMovie) {
        if watchlistMovieIDs.contains(movie.id) {
            watchlistMovieIDs.remove(movie.id)
        } else {
            watchlistMovieIDs.insert(movie.id)
        }
    }

    func isInWatchlist(_ movie: TMDBMovie) -> Bool {
        watchlistMovieIDs.contains(movie.id)
    }

    func toggleSeen(_ movie: TMDBMovie) {
        if seenMovieIDs.contains(movie.id) {
            seenMovieIDs.remove(movie.id)
        } else {
            seenMovieIDs.insert(movie.id)
            if let ids = movie.genreIDs {
                tasteProfile.record(genreIDs: ids)
            }
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
            // If it's "Not for me", clean up other states for that movie
            favorites.remove(movie.id)
            watchlistMovieIDs.remove(movie.id)
            // optional: keep "seen" as true so they know they've already seen it
        }
    }

    func isDisliked(_ movie: TMDBMovie) -> Bool {
        dislikedMovieIDs.contains(movie.id)
    }

    func userSelectedMode(_ newMode: Mode) {
        mode = newMode
        // Reload is handled in didSet
    }

    /// Called when user opens a movie detail screen
    func recordDetailOpen(_ movie: TMDBMovie) {
        detailOpenCount &+= 1
        if let ids = movie.genreIDs {
            tasteProfile.record(genreIDs: ids)
        }
        maybeShowTipNudge(reason: .detail)
    }

    func dismissTipNudge() {
        showTipNudge = false
    }

    func recordTipSuccess() {
        // Could persist a “hasTipped” flag here if you want to avoid future nudges
        showTipNudge = false
    }

    // MARK: - Private

    private enum NudgeReason {
        case shuffle
        case detail
    }

    private func maybeShowTipNudge(reason: NudgeReason) {
        switch reason {
        case .shuffle where shuffleCount == 8:
            tipNudgeMessage = "Loving the Discover shuffle? 🍿 Consider fueling FilmFuel with a small tip!"
            showTipNudge = true
        case .detail where detailOpenCount == 5:
            tipNudgeMessage = "Enjoying all these deep dives? 🎬 A tiny tip helps keep FilmFuel going."
            showTipNudge = true
        default:
            break
        }
    }

    private func reloadForMode() async {
        // If user is actively searching, don't override search results
        guard searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isSearching = false
        isLoading = true
        errorMessage = nil

        do {
            if filters.isActive {
                // When any filter is active, use filtered discover
                try await loadFilteredMoviesForCurrentMode()
            } else {
                // No filters: use your original per-mode behavior
                switch mode {
                case .random:
                    try await loadRandomMovies()
                case .trending:
                    try await loadTrendingMovies()
                case .popular:
                    try await loadPopularMovies()
                }
            }
        } catch {
            errorMessage = "Could not load movies. Please try again."
            print("TMDB error: \(error)")
        }

        isLoading = false
    }

    /// Filtered mode:
    /// Use /discover/movie with FilmFuel filters, then:
    /// - For .random: shuffle the results & cap length
    /// - For .trending / .popular: rely on sort_by
    private func loadFilteredMoviesForCurrentMode() async throws {
        // Use user-selected sort (defaults to popularity.desc)
        let sortBy = filters.sort.tmdbSortKey

        // Build watch provider IDs from selected streaming services
        let providerIDs: [Int]? = filters.selectedStreamingServices.isEmpty
            ? nil
            : filters.selectedStreamingServices.map { $0.providerID }

        // Runtime: interpret presets + custom
        let preset = filters.runtimePreset
        let runtimeMin: Int?
        let runtimeMax: Int?

        if preset == .any {
            runtimeMin = nil
            runtimeMax = nil
        } else {
            runtimeMin = filters.customMinRuntime
            runtimeMax = filters.customMaxRuntime
        }

        // Premium actor/director filters:
        let actorName = filters.actorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let directorName = filters.directorName.trimmingCharacters(in: .whitespacesAndNewlines)

        var actorID: Int? = nil
        var directorID: Int? = nil

        if !actorName.isEmpty {
            actorID = try? await client.searchPersonID(
                named: actorName,
                departmentHint: .acting
            )
        }

        if !directorName.isEmpty {
            directorID = try? await client.searchPersonID(
                named: directorName,
                departmentHint: .directing
            )
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

        if mode == .random {
            randomReloadCount &+= 1
        }

        let response = try await client.fetchFilteredDiscoverMovies(
            page: 1,
            params: params
        )

        var withImages = response.results.filter { movie in
            movie.posterPath != nil && movie.voteCount >= 20
        }

        if mode == .random {
            let currentSeed = randomBaseSeed &+ randomReloadCount
            var shuffleRNG = SeededGenerator(seed: currentSeed &+ 10_000)
            withImages.shuffle(using: &shuffleRNG)
            withImages = Array(withImages.prefix(maxRandomMovies))
        }

        movies = withImages
    }

    /// Original Random mode (no filters)
    private func loadRandomMovies() async throws {
        randomReloadCount &+= 1
        let currentSeed = randomBaseSeed &+ randomReloadCount

        // --- Step 1: get discover page 1 for totalPages ---
        let firstDiscover = try await client.fetchDiscoverMovies(
            page: 1,
            sortBy: "popularity.desc"
        )

        let totalPages = max(1, min(firstDiscover.totalPages, 500)) // Safety cap
        var allResults: [TMDBMovie] = firstDiscover.results

        // --- Step 2: fetch Trending + Popular to build an exclusion set ---
        var excludedIDs = Set<Int>()
        if let trending = try? await client.fetchTrendingMovies(page: 1) {
            for m in trending.results {
                excludedIDs.insert(m.id)
            }
        }
        if let popular = try? await client.fetchPopularMovies(page: 1) {
            for m in popular.results {
                excludedIDs.insert(m.id)
            }
        }

        // --- Step 3: choose random discover pages (seeded) ---
        var pages = Set<Int>()
        pages.insert(1)

        var pageRNG = SeededGenerator(seed: currentSeed)

        while pages.count < randomPagesToLoad && pages.count < totalPages {
            let p = Int.random(in: 1...totalPages, using: &pageRNG)
            pages.insert(p)
        }

        // --- Step 4: fetch remaining random pages from discover ---
        for page in pages where page != 1 {
            let resp = try await client.fetchDiscoverMovies(
                page: page,
                sortBy: "popularity.desc"
            )
            allResults.append(contentsOf: resp.results)
        }

        // --- Step 5: require poster + enough votes + exclude Trending/Popular IDs ---
        var withImages = allResults.filter { movie in
            movie.posterPath != nil &&
            movie.voteCount >= 20 &&
            !excludedIDs.contains(movie.id)
        }

        // De-duplicate within this batch by ID
        var seenInBatch = Set<Int>()
        withImages.removeAll { movie in
            if seenInBatch.contains(movie.id) {
                return true
            } else {
                seenInBatch.insert(movie.id)
                return false
            }
        }

        // --- Step 6: prefer movies we have NOT seen before in random lifetime ---
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

        // --- Step 7: seeded shuffle & cap feed length ---
        var shuffleRNG = SeededGenerator(seed: currentSeed &+ 10_000)
        let shuffled = unseen.shuffled(using: &shuffleRNG)
        var feed = Array(shuffled.prefix(maxRandomMovies))

        // --- Step 8: apply random flavor shaping ---
        switch randomFlavor {
        case .pure:
            break
        case .hotRightNow:
            feed = feed.sorted { lhs, rhs in
                if lhs.voteAverage == rhs.voteAverage {
                    return lhs.voteCount > rhs.voteCount
                }
                return lhs.voteAverage > rhs.voteAverage
            }
        case .criticallyAcclaimed:
            feed = feed.filter { $0.voteAverage >= 7.7 }
        case .fromYourTaste:
            if !tasteProfile.topGenreIDs.isEmpty {
                feed = feed.sorted { lhs, rhs in
                    let s0 = tasteProfile.score(for: lhs)
                    let s1 = tasteProfile.score(for: rhs)

                    if s0 == s1 {
                        return lhs.voteAverage > rhs.voteAverage
                    }
                    return s0 > s1
                }
            }
        }

        // --- Step 9: update seen sets & persist lifetime ---
        let newIDs = feed.map { $0.id }
        sessionSeenRandomMovieIDs.formUnion(newIDs)
        lifetimeSeenRandomMovieIDs.formUnion(newIDs)

        if lifetimeSeenRandomMovieIDs.count > maxLifetimeSeenCount {
            var rng = SeededGenerator(seed: currentSeed &+ 20_000)
            let trimmed = Array(lifetimeSeenRandomMovieIDs)
                .shuffled(using: &rng)
                .prefix(maxLifetimeSeenCount)
            lifetimeSeenRandomMovieIDs = Set(trimmed)
        }

        RandomSeenStore.save(lifetimeSeenRandomMovieIDs)

        movies = feed
    }

    private func loadTrendingMovies() async throws {
        let response = try await client.fetchTrendingMovies(page: 1)

        let withImages = response.results.filter { movie in
            movie.posterPath != nil && movie.voteCount >= 20
        }
        movies = withImages
    }

    private func loadPopularMovies() async throws {
        let response = try await client.fetchPopularMovies(page: 1)

        let withImages = response.results.filter { movie in
            movie.posterPath != nil && movie.voteCount >= 20
        }
        movies = withImages
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

            let withImages = response.results.filter { movie in
                movie.posterPath != nil && movie.voteCount >= 20
            }
            movies = withImages
        } catch {
            errorMessage = "Search failed. Please try again."
            print("TMDB search error: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Seeded RNG

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed))
        if self.state == 0 {
            self.state = 0xdead_beef
        }
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}
