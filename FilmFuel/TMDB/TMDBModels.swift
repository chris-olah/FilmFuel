//
//  TMDBModels.swift
//  FilmFuel
//
//  Created by Chris Olah on 11/22/25.
//

import Foundation

// MARK: - List Response

struct TMDBMovieListResponse: Decodable {
    let page: Int
    let results: [TMDBMovie]
    let totalPages: Int
    let totalResults: Int

    private enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

// MARK: - Movie Model

struct TMDBMovie: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let voteAverage: Double
    let voteCount: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case posterPath   = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate  = "release_date"
        case voteAverage  = "vote_average"
        case voteCount    = "vote_count"
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
