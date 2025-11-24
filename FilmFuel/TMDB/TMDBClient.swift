import Foundation

// MARK: - Discover Params (for filtered /discover calls)

struct TMDBDiscoverParams {
    /// TMDB sort_by value, e.g. "popularity.desc" or "vote_average.desc"
    var sortBy: String?

    /// Minimum vote_average (0–10)
    var minRating: Double?

    /// Optional release year lower bound (e.g. 1990)
    var minYear: Int?

    /// Optional release year upper bound (e.g. 1999)
    var maxYear: Int?

    /// TMDB genre IDs to include (e.g. [28, 35])
    var genreIDs: [Int]?

    /// TMDB watch provider IDs (e.g. 8 = Netflix, 9 = Prime Video, etc.)
    /// Used with `with_watch_providers`
    var watchProviderIDs: [Int]?

    /// Region code for streaming availability (e.g. "US", "GB")
    /// Used with `watch_region`
    var watchRegion: String?

    // PREMIUM FIELDS

    /// Minimum runtime in minutes (mapped to `with_runtime.gte`)
    var minRuntime: Int?

    /// Maximum runtime in minutes (mapped to `with_runtime.lte`)
    var maxRuntime: Int?

    /// TMDB person ID for actor (mapped to `with_cast`)
    var actorPersonID: Int?

    /// TMDB person ID for director (mapped to `with_crew`)
    var directorPersonID: Int?
}

enum TMDBError: Error {
    case invalidURL
    case requestFailed
    case decodingFailed
    case missingAPIKey
}

// Hint for which department we prefer when resolving a person name
enum TMDBDepartmentHint {
    case any
    case acting
    case directing
}

// MARK: - Protocol

protocol TMDBClientProtocol {
    func fetchPopularMovies(page: Int) async throws -> TMDBMovieListResponse
    func fetchTrendingMovies(page: Int) async throws -> TMDBMovieListResponse
    func searchMovies(query: String, page: Int) async throws -> TMDBMovieListResponse
    func fetchDiscoverMovies(page: Int, sortBy: String) async throws -> TMDBMovieListResponse

    // Filtered discover using FilmFuel filters
    func fetchFilteredDiscoverMovies(
        page: Int,
        params: TMDBDiscoverParams
    ) async throws -> TMDBMovieListResponse

    // Movie Detail / Recs
    func fetchMovieDetail(id: Int) async throws -> TMDBMovieDetail
    func fetchMovieRecommendations(id: Int, page: Int) async throws -> TMDBMovieListResponse

    // Used by premium filters (actor/director)
    func searchPersonID(named: String, departmentHint: TMDBDepartmentHint) async throws -> Int?
}

// MARK: - TMDB Client

final class TMDBClient: TMDBClientProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private func makeRequest(path: String, queryItems: [URLQueryItem]) throws -> URLRequest {
        guard !TMDBConfig.apiKey.isEmpty else {
            throw TMDBError.missingAPIKey
        }

        var components = URLComponents(
            url: TMDBConfig.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )

        var items = queryItems
        items.append(URLQueryItem(name: "api_key", value: TMDBConfig.apiKey))
        components?.queryItems = items

        guard let url = components?.url else {
            throw TMDBError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw TMDBError.requestFailed
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw TMDBError.decodingFailed
        }
    }

    // MARK: - Public API (existing)

    func fetchPopularMovies(page: Int = 1) async throws -> TMDBMovieListResponse {
        let request = try makeRequest(
            path: "movie/popular",
            queryItems: [
                URLQueryItem(name: "page", value: String(page))
            ]
        )
        return try await perform(request, as: TMDBMovieListResponse.self)
    }

    func fetchTrendingMovies(page: Int = 1) async throws -> TMDBMovieListResponse {
        let request = try makeRequest(
            path: "trending/movie/day",
            queryItems: [
                URLQueryItem(name: "page", value: String(page))
            ]
        )
        return try await perform(request, as: TMDBMovieListResponse.self)
    }

    func searchMovies(query: String, page: Int = 1) async throws -> TMDBMovieListResponse {
        let request = try makeRequest(
            path: "search/movie",
            queryItems: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "include_adult", value: "false")
            ]
        )
        return try await perform(request, as: TMDBMovieListResponse.self)
    }

    func fetchDiscoverMovies(
        page: Int = 1,
        sortBy: String = "popularity.desc"
    ) async throws -> TMDBMovieListResponse {
        let request = try makeRequest(
            path: "discover/movie",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "sort_by", value: sortBy),
                URLQueryItem(name: "include_adult", value: "false")
            ]
        )
        return try await perform(request, as: TMDBMovieListResponse.self)
    }

    // MARK: - Filtered Discover

    func fetchFilteredDiscoverMovies(
        page: Int = 1,
        params: TMDBDiscoverParams
    ) async throws -> TMDBMovieListResponse {
        var items: [URLQueryItem] = []

        // Page
        items.append(URLQueryItem(name: "page", value: String(page)))

        // Sort
        let sortBy = params.sortBy ?? "popularity.desc"
        items.append(URLQueryItem(name: "sort_by", value: sortBy))

        // Adult content disabled
        items.append(URLQueryItem(name: "include_adult", value: "false"))

        // Minimum rating
        if let minRating = params.minRating, minRating > 0 {
            items.append(
                URLQueryItem(
                    name: "vote_average.gte",
                    value: String(minRating)
                )
            )
        }

        // Year bounds -> dates
        if let minYear = params.minYear {
            let value = "\(minYear)-01-01"
            items.append(
                URLQueryItem(
                    name: "primary_release_date.gte",
                    value: value
                )
            )
        }
        if let maxYear = params.maxYear {
            let value = "\(maxYear)-12-31"
            items.append(
                URLQueryItem(
                    name: "primary_release_date.lte",
                    value: value
                )
            )
        }

        // Genres (OR semantics: 28|35 means Action OR Comedy)
        if let genreIDs = params.genreIDs, !genreIDs.isEmpty {
            let joined = genreIDs.map(String.init).joined(separator: "|")
            items.append(
                URLQueryItem(
                    name: "with_genres",
                    value: joined
                )
            )
        }

        // Streaming providers
        if let providerIDs = params.watchProviderIDs, !providerIDs.isEmpty {
            // OR semantics for providers: 8|9 = Netflix OR Prime Video
            let joined = providerIDs.map(String.init).joined(separator: "|")
            items.append(
                URLQueryItem(
                    name: "with_watch_providers",
                    value: joined
                )
            )

            // Region (default to US if not provided but providers are used)
            let region = params.watchRegion ?? "US"
            items.append(
                URLQueryItem(
                    name: "watch_region",
                    value: region
                )
            )

            // Optional: limit to subscription / free / ad-supported
            items.append(
                URLQueryItem(
                    name: "with_watch_monetization_types",
                    value: "flatrate|free|ads"
                )
            )
        } else if let regionOnly = params.watchRegion {
            // If caller explicitly set a region without providers, we still honor it
            items.append(
                URLQueryItem(
                    name: "watch_region",
                    value: regionOnly
                )
            )
        }

        // PREMIUM: Runtime filters
        if let minRuntime = params.minRuntime {
            items.append(
                URLQueryItem(
                    name: "with_runtime.gte",
                    value: String(minRuntime)
                )
            )
        }
        if let maxRuntime = params.maxRuntime {
            items.append(
                URLQueryItem(
                    name: "with_runtime.lte",
                    value: String(maxRuntime)
                )
            )
        }

        // PREMIUM: Actor / Director filters
        if let actorID = params.actorPersonID {
            items.append(
                URLQueryItem(
                    name: "with_cast",
                    value: String(actorID)
                )
            )
        }
        if let directorID = params.directorPersonID {
            items.append(
                URLQueryItem(
                    name: "with_crew",
                    value: String(directorID)
                )
            )
        }

        let request = try makeRequest(
            path: "discover/movie",
            queryItems: items
        )

        return try await perform(request, as: TMDBMovieListResponse.self)
    }

    // MARK: - Movie Detail + Recommendations

    func fetchMovieDetail(id: Int) async throws -> TMDBMovieDetail {
        let request = try makeRequest(
            path: "movie/\(id)",
            queryItems: []
        )
        return try await perform(request, as: TMDBMovieDetail.self)
    }

    func fetchMovieRecommendations(id: Int, page: Int = 1) async throws -> TMDBMovieListResponse {
        let request = try makeRequest(
            path: "movie/\(id)/recommendations",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "include_adult", value: "false")
            ]
        )
        return try await perform(request, as: TMDBMovieListResponse.self)
    }

    // MARK: - Premium: Person search (actor/director)

    private struct TMDBPersonSearchResponse: Decodable {
        let results: [TMDBPerson]
    }

    private struct TMDBPerson: Decodable {
        let id: Int
        let name: String
        let knownForDepartment: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case knownForDepartment = "known_for_department"
        }
    }

    func searchPersonID(named name: String, departmentHint: TMDBDepartmentHint) async throws -> Int? {
        var components = URLComponents(
            url: TMDBConfig.baseURL.appendingPathComponent("search/person"),
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(name: "api_key", value: TMDBConfig.apiKey),
            URLQueryItem(name: "query", value: name),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "page", value: "1")
        ]

        guard let url = components?.url else {
            throw TMDBError.invalidURL
        }

        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw TMDBError.requestFailed
        }

        let decoded = try JSONDecoder().decode(TMDBPersonSearchResponse.self, from: data)
        guard !decoded.results.isEmpty else { return nil }

        switch departmentHint {
        case .any:
            return decoded.results.first?.id
        case .acting:
            return decoded.results.first(where: { $0.knownForDepartment == "Acting" })?.id
                ?? decoded.results.first?.id
        case .directing:
            return decoded.results.first(where: { $0.knownForDepartment == "Directing" })?.id
                ?? decoded.results.first?.id
        }
    }
}

// MARK: - TMDB Config

enum TMDBConfig {
    static let apiKey = "5b108373b3820fb6f6ccc6a0fba551b6"
    static let baseURL = URL(string: "https://api.themoviedb.org/3")!
    // Image base (you can tweak size; w500 is good for posters)
    static let imageBaseURL = URL(string: "https://image.tmdb.org/t/p/w500")!
}

// MARK: - Models

struct TMDBMovieListResponse: Decodable {
    let page: Int
    let results: [TMDBMovie]
    let totalPages: Int
    let totalResults: Int

    private enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalPages  = "total_pages"
        case totalResults = "total_results"
    }
}

struct TMDBMovie: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let voteAverage: Double
    let voteCount: Int

    /// TMDB list responses provide this as `genre_ids`
    let genreIDs: [Int]?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case posterPath    = "poster_path"
        case backdropPath  = "backdrop_path"
        case releaseDate   = "release_date"
        case voteAverage   = "vote_average"
        case voteCount     = "vote_count"
        case genreIDs      = "genre_ids"
    }

    var yearText: String {
        guard let releaseDate,
              let year = releaseDate.split(separator: "-").first
        else {
            return "—"
        }
        return String(year)
    }

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return TMDBConfig.imageBaseURL.appendingPathComponent(path)
    }

    var backdropURL: URL? {
        guard let path = backdropPath else { return nil }
        return TMDBConfig.imageBaseURL.appendingPathComponent(path)
    }
}

struct TMDBMovieDetail: Decodable {
    let id: Int
    let title: String
    let overview: String
    let runtime: Int?
    let releaseDate: String?
    let genres: [TMDBGenre]
    let voteAverage: Double
    let voteCount: Int
    let backdropPath: String?
    let posterPath: String?
    let tagline: String?

    var yearText: String {
        guard let releaseDate,
              let year = releaseDate.split(separator: "-").first else {
            return "—"
        }
        return String(year)
    }

    var runtimeText: String {
        guard let runtime else { return "—" }
        let hours = runtime / 60
        let mins  = runtime % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case runtime
        case releaseDate   = "release_date"
        case genres
        case voteAverage   = "vote_average"
        case voteCount     = "vote_count"
        case backdropPath  = "backdrop_path"
        case posterPath    = "poster_path"
        case tagline
    }
}

struct TMDBGenre: Decodable, Identifiable {
    let id: Int
    let name: String
}
