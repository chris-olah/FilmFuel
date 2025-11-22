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

// MARK: - Lifetime "seen in Random" store

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
            case .random:   return "Random"
            case .trending: return "Trending"
            case .popular:  return "Popular"
            }
        }
    }

    @Published private(set) var movies: [TMDBMovie] = []

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

    @Published var favorites: Set<Int> = FavoriteStore.load() {
        didSet { FavoriteStore.save(favorites) }
    }

    private let client: TMDBClientProtocol
    private var isSearching: Bool = false

    // How many random pages to sample in Random mode
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

    func toggleFavorite(_ movie: TMDBMovie) {
        if favorites.contains(movie.id) {
            favorites.remove(movie.id)
        } else {
            favorites.insert(movie.id)
        }
    }

    func isFavorite(_ movie: TMDBMovie) -> Bool {
        favorites.contains(movie.id)
    }

    func userSelectedMode(_ newMode: Mode) {
        mode = newMode
        // Reload is handled in didSet
    }

    // MARK: - Private

    private func reloadForMode() async {
        // If user is actively searching, don't override search results
        guard searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isSearching = false
        isLoading = true
        errorMessage = nil

        do {
            switch mode {
            case .random:
                try await loadRandomMovies()
            case .trending:
                try await loadTrendingMovies()
            case .popular:
                try await loadPopularMovies()
            }
        } catch {
            errorMessage = "Could not load movies. Please try again."
            print("TMDB error: \(error)")
        }

        isLoading = false
    }

    /// Random mode:
    /// 1) Fetch discover page 1 to learn totalPages.
    /// 2) Fetch Trending + Popular (page 1) and build an exclusion set of IDs.
    /// 3) Choose a few random page numbers (seeded) from discover.
    /// 4) Fetch each, require poster + min votes, exclude trending/popular IDs,
    ///    prefer unseen (session + lifetime), then seeded-shuffle.
    private func loadRandomMovies() async throws {
        // Advance a counter so each reload uses a different seed,
        // but still deterministic for this VM lifetime.
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

        // --- Step 6: prefer movies we have NOT seen before ---
        var unseen = withImages.filter {
            !sessionSeenRandomMovieIDs.contains($0.id) &&
            !lifetimeSeenRandomMovieIDs.contains($0.id)
        }

        if unseen.isEmpty {
            // We've basically exhausted our lifetime variety cache;
            // reset lifetime and session so we can see repeats again.
            sessionSeenRandomMovieIDs = []
            lifetimeSeenRandomMovieIDs = []
            RandomSeenStore.save(lifetimeSeenRandomMovieIDs)

            // Still keep them excluded from trending/popular, just reset "seen".
            unseen = withImages
        }

        // --- Step 7: seeded shuffle & cap feed length ---
        var shuffleRNG = SeededGenerator(seed: currentSeed &+ 10_000)
        let shuffled = unseen.shuffled(using: &shuffleRNG)
        let finalMovies = Array(shuffled.prefix(maxRandomMovies))

        // --- Step 8: update seen sets & persist lifetime ---
        let newIDs = finalMovies.map { $0.id }
        sessionSeenRandomMovieIDs.formUnion(newIDs)
        lifetimeSeenRandomMovieIDs.formUnion(newIDs)

        // Keep lifetime cache from growing unbounded
        if lifetimeSeenRandomMovieIDs.count > maxLifetimeSeenCount {
            var rng = SeededGenerator(seed: currentSeed &+ 20_000)
            let trimmed = Array(lifetimeSeenRandomMovieIDs)
                .shuffled(using: &rng)
                .prefix(maxLifetimeSeenCount)
            lifetimeSeenRandomMovieIDs = Set(trimmed)
        }

        RandomSeenStore.save(lifetimeSeenRandomMovieIDs)

        movies = finalMovies
    }

    private func loadTrendingMovies() async throws {
        let response = try await client.fetchTrendingMovies(page: 1)

        // Require a poster + enough votes for trending feed
        let withImages = response.results.filter { movie in
            movie.posterPath != nil && movie.voteCount >= 20
        }
        movies = withImages
    }

    private func loadPopularMovies() async throws {
        let response = try await client.fetchPopularMovies(page: 1)

        // Require a poster + enough votes for popular feed
        let withImages = response.results.filter { movie in
            movie.posterPath != nil && movie.voteCount >= 20
        }
        movies = withImages
    }

    private func handleSearchChange() async {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            // Clear search → go back to mode feed
            isSearching = false
            await reloadForMode()
            return
        }

        isSearching = true
        isLoading = true
        errorMessage = nil

        do {
            let response = try await client.searchMovies(query: trimmed, page: 1)

            // Require a poster + enough votes for search results
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
        // Truncate / wrap the Int into 64 bits
        self.state = UInt64(bitPattern: Int64(seed))
        if self.state == 0 {
            self.state = 0xdead_beef  // avoid zero state
        }
    }

    mutating func next() -> UInt64 {
        // Simple LCG
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}
