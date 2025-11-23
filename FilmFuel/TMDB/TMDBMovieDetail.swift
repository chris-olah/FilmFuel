import Foundation

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
