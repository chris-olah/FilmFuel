//
//  DiscoverFilters.swift
//  FilmFuel
//

import Foundation

// MARK: - Streaming services (TMDB watch providers)

enum StreamingService: String, CaseIterable, Identifiable, Hashable {
    case netflix
    case primeVideo
    case disneyPlus
    case hulu
    case max
    case appleTVPlus
    case peacock
    case paramountPlus

    var id: String { rawValue }

    var label: String {
        switch self {
        case .netflix:       return "Netflix"
        case .primeVideo:    return "Prime Video"
        case .disneyPlus:    return "Disney+"
        case .hulu:          return "Hulu"
        case .max:           return "Max"
        case .appleTVPlus:   return "Apple TV+"
        case .peacock:       return "Peacock"
        case .paramountPlus: return "Paramount+"
        }
    }

    /// TMDB watch provider IDs for /discover/movie with `with_watch_providers`
    var providerID: Int {
        switch self {
        case .netflix:       return 8
        case .primeVideo:    return 9
        case .hulu:          return 15
        case .disneyPlus:    return 337
        case .max:           return 384       // HBO Max / Max
        case .appleTVPlus:   return 350
        case .peacock:       return 387
        case .paramountPlus: return 531
        }
    }
}

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

    /// Selected streaming services (TMDB watch providers)
    var selectedStreamingServices: Set<StreamingService> = []

    /// Sort mode (default: popularity)
    var sort: DiscoverSort = .popularity

    static let `default` = DiscoverFilters()

    var isActive: Bool {
        return minRating > 0.0 ||
               minYear != nil ||
               maxYear != nil ||
               onlyFavorites ||
               !selectedGenreIDs.isEmpty ||
               !selectedStreamingServices.isEmpty ||   // 👈 streaming filters count as active
               sort != .popularity                     // non-default sort counts as an "active" filter
    }

    mutating func reset() {
        self = .default
    }
}
