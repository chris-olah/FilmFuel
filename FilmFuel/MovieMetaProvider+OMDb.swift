//
//  MovieMetaProvider+OMDb.swift
//  FilmFuel
//
//  Created by Chris Olah on 11/12/25.
//

import Foundation

// Reuse your Discover model
struct MovieMeta: Equatable, Codable {
    var ratingText: String          // IMDb (e.g., "8.0" or "–")
    var funFact: String
    var summary: String
    var rtTomatometer: String?      // e.g., "90%"
    var metacritic: String?         // e.g., "73/100"

    // MARK: - Extra rich fields from OMDb
    var title: String?              // "The Dark Knight"
    var imdbID: String?             // "tt0468569"
    var actors: String?             // "Christian Bale, Heath Ledger, ..."
    var boxOffice: String?          // "$1,006,234,167"
    var posterURL: String?          // "https://m.media-amazon.com/..."

    // 🏆 Awards (e.g. "Won 2 Oscars. Another 161 wins & 163 nominations.")
    var awards: String?

    // 🎬 Genre (e.g. "Action, Crime, Drama")
    var genre: String?
}

protocol MovieMetaProvider {
    func meta(for movie: String, year: Int, fallbackFunFact: String) async -> MovieMeta
}

// OMDb fields
private struct OMDbResponse: Decodable {
    struct RatingItem: Decodable {
        let Source: String
        let Value: String
    }

    let Title: String?
    let Year: String?
    let Plot: String?
    let imdbRating: String?
    let Ratings: [RatingItem]?
    let Response: String?           // "True"/"False"
    let Error: String?

    // Extra fields we want to use
    let imdbID: String?
    let Actors: String?
    let BoxOffice: String?
    let Poster: String?
    let Metascore: String?
    let Awards: String?             // awards text
    let Genre: String?              // "Action, Crime, Drama" etc.
}

private struct OMDbSearchResponse: Decodable {
    struct Item: Decodable {
        let Title: String
        let Year: String
        let imdbID: String
        let mediaType: String?   // JSON "Type"

        private enum CodingKeys: String, CodingKey {
            case Title, Year, imdbID
            case mediaType = "Type"
        }
    }
    let Search: [Item]?
    let Response: String?
    let Error: String?
}

final class OMDbMovieMetaProvider: MovieMetaProvider {
    private let apiKey: String
    private let groupID = "group.com.chrisolah.FilmFuel"

    // 🚀 bump this to invalidate all old cached entries at once
    private let cacheVersion = "v4"   // ⬅️ bumped from v3 to v4

    private let cacheKeyPrefix = "ff.meta."

    private var suite: UserDefaults { UserDefaults(suiteName: groupID) ?? .standard }

    init(apiKey: String = Secrets.omdbKey) { self.apiKey = apiKey }

    func meta(for movie: String, year: Int, fallbackFunFact: String) async -> MovieMeta {
        let cacheKey = makeCacheKey(movie: movie, year: year)

        // 1) Cached?
        if let data = suite.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(MovieMeta.self, from: data) {

            if isNegativeCache(cached) {
                print("📦 cache (NEGATIVE) -> refetch:", cacheKey)
            } else {
                print("📦 cache hit:", cacheKey, "| genre:", cached.genre ?? "nil")
                return cached
            }
        }

        guard !apiKey.isEmpty else {
            return store(
                MovieMeta(
                    ratingText: "–",
                    funFact: fallbackFunFact.ifEmpty("Cinema tidbit coming soon."),
                    summary: "Missing OMDb API key.",
                    rtTomatometer: nil,
                    metacritic: nil,
                    title: nil,
                    imdbID: nil,
                    actors: nil,
                    boxOffice: nil,
                    posterURL: nil,
                    awards: nil,
                    genre: nil
                ),
                as: cacheKey
            )
        }

        // ——— Lookup cascade ———
        // A) title + year (when year > 0)
        if let res = await fetch(title: movie, year: (year > 0 ? year : nil)),
           hasUsableRatingsOrPlot(res) {
            return store(toMeta(res, fallbackFunFact: fallbackFunFact), as: cacheKey)
        }

        // B) title only
        if let res = await fetch(title: movie, year: nil),
           hasUsableRatingsOrPlot(res) {
            return store(toMeta(res, fallbackFunFact: fallbackFunFact), as: cacheKey)
        }

        // C) normalized title (strip parens/subtitles/punctuation)
        let normalized = normalizeTitle(movie)
        if normalized != movie {
            if let res = await fetch(title: normalized, year: (year > 0 ? year : nil)),
               hasUsableRatingsOrPlot(res) {
                return store(toMeta(res, fallbackFunFact: fallbackFunFact), as: cacheKey)
            }
            if let res = await fetch(title: normalized, year: nil),
               hasUsableRatingsOrPlot(res) {
                return store(toMeta(res, fallbackFunFact: fallbackFunFact), as: cacheKey)
            }
        }

        // D) Final fallback: search (`s=`) then fetch by imdbID (`i=`)
        if let res = await searchAndFetchBest(title: movie, year: year) {
            return store(toMeta(res, fallbackFunFact: fallbackFunFact), as: cacheKey)
        }

        // Not found (store as negative to avoid rapid re-hits; still refetch next app run)
        return store(
            MovieMeta(
                ratingText: "–",
                funFact: fallbackFunFact.ifEmpty("Cinema tidbit coming soon."),
                summary: "Summary unavailable.",
                rtTomatometer: nil,
                metacritic: nil,
                title: nil,
                imdbID: nil,
                actors: nil,
                boxOffice: nil,
                posterURL: nil,
                awards: nil,
                genre: nil
            ),
            as: cacheKey
        )
    }

    // MARK: - Networking

    private func fetch(title: String, year: Int?) async -> OMDbResponse? {
        guard let url = buildTitleURL(title: title, year: year) else { return nil }
        print("🔎 OMDb URL:", url.absoluteString)
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(OMDbResponse.self, from: data)
        } catch {
            print("⚠️ OMDb error:", error.localizedDescription)
            return nil
        }
    }

    private func fetchByID(_ imdbID: String) async -> OMDbResponse? {
        guard let url = buildIDURL(imdbID: imdbID) else { return nil }
        print("🔎 OMDb URL (by id):", url.absoluteString)
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(OMDbResponse.self, from: data)
        } catch {
            print("⚠️ OMDb (id) error:", error.localizedDescription)
            return nil
        }
    }

    private func searchAndFetchBest(title: String, year: Int) async -> OMDbResponse? {
        guard let url = buildSearchURL(query: title) else { return nil }
        print("🔎 OMDb URL (search):", url.absoluteString)
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let result = try JSONDecoder().decode(OMDbSearchResponse.self, from: data)
            guard (result.Response ?? "False") == "True",
                  let list = result.Search,
                  !list.isEmpty else { return nil }

            // prefer movies; then prefer matching year if feasible
            let movies = list.filter { ($0.mediaType ?? "movie") == "movie" }
            let pick: OMDbSearchResponse.Item? = {
                if year > 0 {
                    return movies.first(where: { $0.Year.contains(String(year)) }) ?? movies.first
                }
                return movies.first
            }()

            if let id = pick?.imdbID {
                return await fetchByID(id)
            }
            return nil
        } catch {
            print("⚠️ OMDb (search) error:", error.localizedDescription)
            return nil
        }
    }

    // IMPORTANT: do NOT pre-percent-encode the title.
    // URLComponents will safely encode queryItems for us.
    private func buildTitleURL(title: String, year: Int?) -> URL? {
        var comps = URLComponents(string: "https://www.omdbapi.com/")!
        var items: [URLQueryItem] = [
            .init(name: "t", value: title),
            .init(name: "plot", value: "short"),
            .init(name: "type", value: "movie"),
            .init(name: "r", value: "json"),
            .init(name: "apikey", value: apiKey)
        ]
        if let y = year, y > 0 {
            items.append(.init(name: "y", value: String(y)))
        }
        comps.queryItems = items
        return comps.url
    }

    private func buildIDURL(imdbID: String) -> URL? {
        var comps = URLComponents(string: "https://www.omdbapi.com/")!
        comps.queryItems = [
            .init(name: "i", value: imdbID),
            .init(name: "plot", value: "short"),
            .init(name: "r", value: "json"),
            .init(name: "apikey", value: apiKey)
        ]
        return comps.url
    }

    private func buildSearchURL(query: String) -> URL? {
        var comps = URLComponents(string: "https://www.omdbapi.com/")!
        comps.queryItems = [
            .init(name: "s", value: query),
            .init(name: "type", value: "movie"),
            .init(name: "r", value: "json"),
            .init(name: "apikey", value: apiKey)
        ]
        return comps.url
    }

    // MARK: - Parsing helpers

    private func toMeta(_ r: OMDbResponse, fallbackFunFact: String) -> MovieMeta {
        let imdb = sanitize(r.imdbRating)
        var rt: String?
        var mc: String?

        // Rotten + Metacritic from Ratings list
        r.Ratings?.forEach { item in
            if item.Source == "Rotten Tomatoes" {
                rt = sanitize(item.Value)
            }
            if item.Source == "Metacritic" {
                mc = sanitize(item.Value)
            }
        }

        // Prefer explicit Metascore if present
        if let metascore = sanitize(r.Metascore) {
            mc = metascore
        }

        let plotText: String
        if let p = r.Plot, !p.isEmpty, p != "N/A" {
            plotText = p
        } else {
            plotText = "No plot summary available."
        }

        // 🔧 Explicitly clean full genre string from OMDb
        let cleanedGenre: String? = {
            guard let raw = r.Genre,
                  !raw.isEmpty,
                  raw != "N/A" else { return nil }
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }()

        let meta = MovieMeta(
            ratingText: imdb ?? "–",
            funFact: fallbackFunFact.ifEmpty("Cinema tidbit coming soon."),
            summary: plotText,
            rtTomatometer: rt,
            metacritic: mc,
            title: sanitize(r.Title),
            imdbID: sanitize(r.imdbID),
            actors: sanitize(r.Actors),
            boxOffice: sanitize(r.BoxOffice),
            posterURL: sanitize(r.Poster),
            awards: sanitize(r.Awards),
            genre: cleanedGenre          // ✅ keep full OMDb genre, e.g. "Action, Crime, Drama"
        )

        print("🎬 OMDb meta built for",
              meta.title ?? "<unknown>",
              "| year:", r.Year ?? "n/a",
              "| genre:", meta.genre ?? "nil")

        return meta
    }

    private func sanitize(_ value: String?) -> String? {
        guard let s = value,
              !s.isEmpty,
              s != "N/A" else { return nil }
        return s
    }

    private func hasUsableRatingsOrPlot(_ r: OMDbResponse) -> Bool {
        let hasIMDb = sanitize(r.imdbRating) != nil
        let hasRT   = r.Ratings?.contains {
            $0.Source == "Rotten Tomatoes" && $0.Value != "N/A"
        } ?? false
        let hasPlot = (r.Plot?.isEmpty == false && r.Plot != "N/A")
        return hasIMDb || hasRT || hasPlot
    }

    /// Strip content in parentheses and common subtitle separators like ":" "–" "-"
    private func normalizeTitle(_ s: String) -> String {
        var t = s
        if let range = t.range(of: #" ?\(.+?\)"#, options: .regularExpression) {
            t.removeSubrange(range)
        }
        if let idx = t.firstIndex(of: ":") { t = String(t[..<idx]) }
        if let idx = t.firstIndex(of: "–") { t = String(t[..<idx]) }
        if let idx = t.firstIndex(of: "-") { t = String(t[..<idx]) }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Cache

    private func makeCacheKey(movie: String, year: Int) -> String {
        // include version to bust stale entries created before fallbacks
        let safe = movie.replacingOccurrences(of: "|", with: "¦")
        return cacheKeyPrefix + "\(safe)|\(year)|\(cacheVersion)"
    }

    private func store(_ meta: MovieMeta, as key: String) -> MovieMeta {
        if let data = try? JSONEncoder().encode(meta) {
            suite.set(data, forKey: key)
        }
        print("💾 cache save:", key, "| genre:", meta.genre ?? "nil")
        return meta
    }

    private func isNegativeCache(_ m: MovieMeta) -> Bool {
        // consider “–” rating + very generic summary as a negative/empty result
        if m.ratingText == "–" {
            let sum = m.summary.lowercased()
            if sum.contains("summary unavailable") || sum.contains("no plot summary") {
                return true
            }
        }
        return false
    }
}

private extension String {
    func ifEmpty(_ alt: @autoclosure () -> String) -> String { isEmpty ? alt() : self }
}
