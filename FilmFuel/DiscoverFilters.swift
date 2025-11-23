//
//  DiscoverFilters.swift
//  FilmFuel
//

import Foundation

// MARK: - Sort options for Discover

enum DiscoverSort: String, CaseIterable, Identifiable, Equatable {
    case popularity
    case rating
    case newest
    case oldest
    case title

    var id: String { rawValue }

    var label: String {
        switch self {
        case .popularity: return "Popular"
        case .rating:     return "Rating"
        case .newest:     return "Newest"
        case .oldest:     return "Oldest"
        case .title:      return "Title A–Z"
        }
    }

    /// TMDB sort_by value
    var tmdbSortKey: String {
        switch self {
        case .popularity:
            return "popularity.desc"
        case .rating:
            return "vote_average.desc"
        case .newest:
            return "primary_release_date.desc"
        case .oldest:
            return "primary_release_date.asc"
        case .title:
            return "original_title.asc"
        }
    }
}

// MARK: - Filters

struct DiscoverFilters: Equatable {
    /// Minimum TMDB rating (0–10)
    var minRating: Double = 0.0

    /// Optional year range, e.g. 1990–2025
    var minYear: Int? = nil
    var maxYear: Int? = nil

    /// Only show movies the user has favorited
    var onlyFavorites: Bool = false

    /// Selected TMDB genre IDs (e.g. 28 = Action, 35 = Comedy)
    var selectedGenreIDs: Set<Int> = []

    /// Sort mode (default: popularity)
    var sort: DiscoverSort = .popularity

    static let `default` = DiscoverFilters()

    var isActive: Bool {
        return minRating > 0.0 ||
               minYear != nil ||
               maxYear != nil ||
               onlyFavorites ||
               !selectedGenreIDs.isEmpty ||
               sort != .popularity   // non-default sort counts as an "active" filter
    }

    mutating func reset() {
        self = .default
    }
}
