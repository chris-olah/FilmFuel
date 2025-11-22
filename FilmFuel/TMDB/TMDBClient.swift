import Foundation

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

    // MARK: - Public API

    func fetchPopularMovies(page: Int = 1) async throws -> TMDBMovieListResponse {
        let request = try makeRequest(
            path: "movie/popular",
            queryItems: [URLQueryItem(name: "page", value: String(page))]
        )
        return try await perform(request, as: TMDBMovieListResponse.self)
    }

    func fetchTrendingMovies(page: Int = 1) async throws -> TMDBMovieListResponse {
        let request = try makeRequest(
            path: "trending/movie/day",
            queryItems: [URLQueryItem(name: "page", value: String(page))]
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
}
