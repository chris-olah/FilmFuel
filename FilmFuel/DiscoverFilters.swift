//
//  DiscoverFilters.swift
//  FilmFuel
//
//  Redesigned with strategic premium gates
//

import Foundation

// MARK: - Streaming Services

enum StreamingService: String, CaseIterable, Identifiable, Hashable {
    case netflix, primeVideo, disneyPlus, hulu, max, appleTVPlus, peacock, paramountPlus
    
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
    
    var providerID: Int {
        switch self {
        case .netflix:       return 8
        case .primeVideo:    return 9
        case .hulu:          return 15
        case .disneyPlus:    return 337
        case .max:           return 384
        case .appleTVPlus:   return 350
        case .peacock:       return 387
        case .paramountPlus: return 531
        }
    }
    
    /// Free users get limited streaming service selection
    var isPremium: Bool {
        switch self {
        case .netflix, .primeVideo, .disneyPlus:
            return false // Free tier
        default:
            return true // Premium only
        }
    }
}

// MARK: - Sort Options

enum DiscoverSort: String, CaseIterable, Identifiable, Equatable {
    case popularity, rating, newest, oldest, title, hidden
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .popularity: return "Popular"
        case .rating:     return "Rating"
        case .newest:     return "Newest"
        case .oldest:     return "Oldest"
        case .title:      return "Title A–Z"
        case .hidden:     return "Hidden Gems"
        }
    }
    
    var tmdbSortKey: String {
        switch self {
        case .popularity: return "popularity.desc"
        case .rating:     return "vote_average.desc"
        case .newest:     return "primary_release_date.desc"
        case .oldest:     return "primary_release_date.asc"
        case .title:      return "original_title.asc"
        case .hidden:     return "vote_average.desc" // Combined with vote count filter
        }
    }
    
    var isPremium: Bool {
        self == .hidden
    }
}

// MARK: - Runtime Presets

enum RuntimePreset: String, CaseIterable, Identifiable {
    case any, short, medium, long, custom
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .any:    return "Any"
        case .short:  return "< 100 min"
        case .medium: return "90–130 min"
        case .long:   return "140+ min"
        case .custom: return "Custom"
        }
    }
    
    var defaultBounds: (min: Int?, max: Int?) {
        switch self {
        case .any:    return (nil, nil)
        case .short:  return (nil, 100)
        case .medium: return (90, 130)
        case .long:   return (140, nil)
        case .custom: return (nil, nil)
        }
    }
    
    var isPremium: Bool {
        self == .custom
    }
}

// MARK: - Genre Categories (for organized display)

enum GenreCategory: String, CaseIterable {
    case popular, action, drama, comedy, other
    
    var label: String {
        switch self {
        case .popular: return "Popular"
        case .action:  return "Action & Adventure"
        case .drama:   return "Drama & Romance"
        case .comedy:  return "Comedy & Family"
        case .other:   return "Other"
        }
    }
    
    var genreIDs: [Int] {
        switch self {
        case .popular: return [28, 35, 18, 27, 10749] // Action, Comedy, Drama, Horror, Romance
        case .action:  return [28, 12, 53, 10752, 878] // Action, Adventure, Thriller, War, Sci-Fi
        case .drama:   return [18, 10749, 80, 36] // Drama, Romance, Crime, History
        case .comedy:  return [35, 10751, 16, 14] // Comedy, Family, Animation, Fantasy
        case .other:   return [99, 9648, 10402, 37, 10770] // Doc, Mystery, Music, Western, TV Movie
        }
    }
}

// MARK: - Filter Presets (Quick filters for engagement)

enum FilterPreset: String, CaseIterable, Identifiable {
    case none
    case dateNight
    case familyFriendly
    case criticsPick
    case hiddenGems
    case newReleases
    case classicCinema
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .none:           return "None"
        case .dateNight:      return "Date Night"
        case .familyFriendly: return "Family Friendly"
        case .criticsPick:    return "Critics' Pick"
        case .hiddenGems:     return "Hidden Gems"
        case .newReleases:    return "New Releases"
        case .classicCinema:  return "Classic Cinema"
        }
    }
    
    var icon: String {
        switch self {
        case .none:           return "slider.horizontal.3"
        case .dateNight:      return "heart.fill"
        case .familyFriendly: return "figure.2.and.child.holdinghands"
        case .criticsPick:    return "star.fill"
        case .hiddenGems:     return "diamond.fill"
        case .newReleases:    return "sparkles"
        case .classicCinema:  return "film.fill"
        }
    }
    
    var isPremium: Bool {
        switch self {
        case .hiddenGems, .criticsPick, .classicCinema:
            return true
        default:
            return false
        }
    }
    
    func applyTo(_ filters: inout DiscoverFilters) {
        switch self {
        case .none:
            filters.reset()
            
        case .dateNight:
            filters.selectedGenreIDs = Set([10749, 35]) // Romance, Comedy
            filters.minRating = 6.5
            filters.runtimePreset = .medium
            
        case .familyFriendly:
            filters.selectedGenreIDs = Set([10751, 16, 14]) // Family, Animation, Fantasy
            filters.minRating = 6.0
            
        case .criticsPick:
            filters.minRating = 8.0
            filters.sort = .rating
            
        case .hiddenGems:
            filters.minRating = 7.0
            filters.sort = .hidden
            
        case .newReleases:
            let currentYear = Calendar.current.component(.year, from: Date())
            filters.minYear = currentYear - 1
            filters.sort = .newest
            
        case .classicCinema:
            filters.maxYear = 1990
            filters.minRating = 7.5
        }
    }
}

// MARK: - Discover Filters

struct DiscoverFilters: Equatable {
    // Basic filters (free)
    var minRating: Double = 0.0
    var minYear: Int? = nil
    var maxYear: Int? = nil
    var onlyFavorites: Bool = false
    var selectedGenreIDs: Set<Int> = []
    
    // Streaming (limited free)
    var selectedStreamingServices: Set<StreamingService> = []
    
    // Sort (mostly free)
    var sort: DiscoverSort = .popularity
    
    // Runtime (premium for custom)
    var runtimePreset: RuntimePreset = .any
    var customMinRuntime: Int? = nil
    var customMaxRuntime: Int? = nil
    
    // Premium filters
    var actorName: String = ""
    var directorName: String = ""
    
    // Current preset (for UI)
    var activePreset: FilterPreset = .none
    
    static let `default` = DiscoverFilters()
    
    var isActive: Bool {
        minRating > 0.0 ||
        minYear != nil ||
        maxYear != nil ||
        onlyFavorites ||
        !selectedGenreIDs.isEmpty ||
        !selectedStreamingServices.isEmpty ||
        sort != .popularity ||
        runtimePreset != .any ||
        customMinRuntime != nil ||
        customMaxRuntime != nil ||
        !actorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !directorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Count of active filters (for badge display)
    var activeFilterCount: Int {
        var count = 0
        if minRating > 0.0 { count += 1 }
        if minYear != nil || maxYear != nil { count += 1 }
        if onlyFavorites { count += 1 }
        if !selectedGenreIDs.isEmpty { count += 1 }
        if !selectedStreamingServices.isEmpty { count += 1 }
        if sort != .popularity { count += 1 }
        if runtimePreset != .any { count += 1 }
        if !actorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if !directorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        return count
    }
    
    /// Returns which premium features are being used
    var premiumFeaturesInUse: [String] {
        var features: [String] = []
        
        // Premium streaming services
        let premiumStreaming = selectedStreamingServices.filter { $0.isPremium }
        if !premiumStreaming.isEmpty {
            features.append("Premium streaming filters")
        }
        
        // Hidden gems sort
        if sort.isPremium {
            features.append("Hidden Gems sorting")
        }
        
        // Custom runtime
        if runtimePreset.isPremium {
            features.append("Custom runtime filter")
        }
        
        // Actor/Director
        if !actorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            features.append("Actor filter")
        }
        if !directorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            features.append("Director filter")
        }
        
        return features
    }
    
    var requiresPremium: Bool {
        !premiumFeaturesInUse.isEmpty
    }
    
    mutating func applyRuntimePresetIfNeeded() {
        guard runtimePreset != .custom else { return }
        let bounds = runtimePreset.defaultBounds
        customMinRuntime = bounds.min
        customMaxRuntime = bounds.max
    }
    
    mutating func reset() {
        self = .default
    }
    
    mutating func applyPreset(_ preset: FilterPreset) {
        activePreset = preset
        preset.applyTo(&self)
    }
}

// MARK: - Genre Info (for display)

struct GenreInfo: Identifiable, Hashable {
    let id: Int
    let name: String
    let icon: String
    let isPremium: Bool
    
    static let all: [GenreInfo] = [
        GenreInfo(id: 28, name: "Action", icon: "bolt.fill", isPremium: false),
        GenreInfo(id: 12, name: "Adventure", icon: "map.fill", isPremium: false),
        GenreInfo(id: 16, name: "Animation", icon: "paintpalette.fill", isPremium: false),
        GenreInfo(id: 35, name: "Comedy", icon: "face.smiling.fill", isPremium: false),
        GenreInfo(id: 80, name: "Crime", icon: "exclamationmark.shield.fill", isPremium: false),
        GenreInfo(id: 99, name: "Documentary", icon: "doc.text.fill", isPremium: true),
        GenreInfo(id: 18, name: "Drama", icon: "theatermasks.fill", isPremium: false),
        GenreInfo(id: 10751, name: "Family", icon: "figure.2.and.child.holdinghands", isPremium: false),
        GenreInfo(id: 14, name: "Fantasy", icon: "wand.and.stars", isPremium: false),
        GenreInfo(id: 36, name: "History", icon: "clock.fill", isPremium: true),
        GenreInfo(id: 27, name: "Horror", icon: "theatermasks.fill", isPremium: false),
        GenreInfo(id: 10402, name: "Music", icon: "music.note", isPremium: true),
        GenreInfo(id: 9648, name: "Mystery", icon: "magnifyingglass", isPremium: false),
        GenreInfo(id: 10749, name: "Romance", icon: "heart.fill", isPremium: false),
        GenreInfo(id: 878, name: "Sci-Fi", icon: "sparkles", isPremium: false),
        GenreInfo(id: 10770, name: "TV Movie", icon: "tv.fill", isPremium: true),
        GenreInfo(id: 53, name: "Thriller", icon: "exclamationmark.triangle.fill", isPremium: false),
        GenreInfo(id: 10752, name: "War", icon: "shield.fill", isPremium: true),
        GenreInfo(id: 37, name: "Western", icon: "sun.dust.fill", isPremium: true),
    ]
    
    static func genre(for id: Int) -> GenreInfo? {
        all.first { $0.id == id }
    }
    
    static var freeGenres: [GenreInfo] {
        all.filter { !$0.isPremium }
    }
    
    static var premiumGenres: [GenreInfo] {
        all.filter { $0.isPremium }
    }
}
