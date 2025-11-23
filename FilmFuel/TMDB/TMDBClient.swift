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
}

enum TMDBError: Error {
    case invalidURL
    case requestFailed
    case decodingFailed
    case missingAPIKey
}

protocol TMDBClientProtocol {
    func fetchPopularMovies(page: Int) async throws -> TMDBMovieListResponse
    func fetchTrendingMovies(page: Int) async throws -> TMDBMovieListResponse
    func searchMovies(query: String, page: Int) async throws -> TMDBMovieListResponse
    func fetchDiscoverMovies(page: Int, sortBy: String) async throws -> TMDBMovieListResponse

    // 🔹 New: filtered discover using FilmFuel filters
    func fetchFilteredDiscoverMovies(
        page: Int,
        params: TMDBDiscoverParams
    ) async throws -> TMDBMovieListResponse

    // 🔹 Movie Detail / Recs
    func fetchMovieDetail(id: Int) async throws -> TMDBMovieDetail
    func fetchMovieRecommendations(id: Int, page: Int) async throws -> TMDBMovieListResponse
}

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

    // MARK: - New: Filtered Discover

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
            queryItems: [
                // If you want: URLQueryItem(name: "language", value: "en-US")
            ]
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
}
