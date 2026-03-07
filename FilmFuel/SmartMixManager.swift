//
//  SmartMixManager.swift
//  FilmFuel
//

import Foundation
import SwiftUI

// MARK: - Smart Mix

struct SmartMix: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let iconSystemName: String
    let movies: [TMDBMovie]
    let isPremium: Bool
    let badge: MixBadge?
    let engagementHook: String?

    init(
        title: String,
        subtitle: String,
        iconSystemName: String,
        movies: [TMDBMovie],
        isPremium: Bool = false,
        badge: MixBadge? = nil,
        engagementHook: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconSystemName = iconSystemName
        self.movies = movies
        self.isPremium = isPremium
        self.badge = badge
        self.engagementHook = engagementHook
    }
}

// MARK: - Mix Badge

enum MixBadge: String {
    case new
    case hot
    case exclusive
    case limited
    case personalized

    var color: Color {
        switch self {
        case .new: return .green
        case .hot: return .orange
        case .exclusive: return .purple
        case .limited: return .red
        case .personalized: return .blue
        }
    }
}

// MARK: - Smart Mix Manager

enum SmartMixManager {

    // MARK: - Main Builder

    static func buildMixes(
        from movies: [TMDBMovie],
        mood: MovieMood,
        tasteProfile: TasteProfile,
        isPremium: Bool,
        userLevel: UserLevel = .newbie
    ) -> [SmartMix] {

        guard !movies.isEmpty else { return [] }

        var mixes: [SmartMix] = []

        if let personalized = buildPersonalizedMix(
            movies: movies,
            tasteProfile: tasteProfile,
            isPremium: isPremium
        ) {
            mixes.append(personalized)
        }

        if mood != .any {
            if let moodMix = buildMoodMix(mood: mood, movies: movies) {
                mixes.append(moodMix)
            }
        }

        if let spotlight = buildWeeklySpotlight(movies: movies) {
            mixes.append(spotlight)
        }

        if let comfort = buildComfortQueue(movies: movies) { mixes.append(comfort) }
        if let thrills = buildThrillsAndTwists(movies: movies) { mixes.append(thrills) }
        if let dateNight = buildDateNightStack(movies: movies) { mixes.append(dateNight) }
        if let newReleases = buildNewReleases(movies: movies, isPremium: isPremium) { mixes.append(newReleases) }

        if let gems = buildHiddenGems(movies: movies, isPremium: isPremium) { mixes.append(gems) }
        if let critics = buildCriticsChoice(movies: movies, isPremium: isPremium) { mixes.append(critics) }

        if let decade = tasteProfile.favoriteDecade,
           let decadeMix = buildDecadeDive(decade: decade, movies: movies, isPremium: isPremium) {
            mixes.append(decadeMix)
        }

        if let shortFilms = buildShortAndSweet(movies: movies) { mixes.append(shortFilms) }

        if let mindBlown = buildMindBlownMix(movies: movies) { mixes.append(mindBlown) }

        // Remove duplicate mix titles
        var seenTitles = Set<String>()
        let dedupedMixes = mixes.filter { seenTitles.insert($0.title).inserted }

        // Remove duplicate movies across mixes
        let uniqueMovies = removeDuplicateMovies(from: dedupedMixes)

        // Rank mixes
        let ranked = rankMixes(uniqueMovies)

        return Array(ranked.prefix(8))
    }

    // MARK: - Personalized Mix

    private static func buildPersonalizedMix(
        movies: [TMDBMovie],
        tasteProfile: TasteProfile,
        isPremium: Bool
    ) -> SmartMix? {

        guard !tasteProfile.topGenreIDs.isEmpty else { return nil }

        let scored = movies.map { movie -> (TMDBMovie, Double) in

            var score = Double(tasteProfile.score(for: movie))

            if let genres = movie.genreIDs {
                for g in genres {
                    if tasteProfile.topGenreIDs.contains(g) {
                        score += 2.0
                    }
                }
            }

            score += movie.voteAverage * 0.5

            return (movie, score)
        }

        let sorted = scored.sorted { $0.1 > $1.1 }

        guard !sorted.isEmpty else { return nil }

        let fullCount = sorted.count
        let limit = isPremium ? min(fullCount, 20) : min(fullCount, 5)

        var picks = Array(sorted.prefix(limit)).map { $0.0 }

        picks = injectSurprises(into: picks, from: movies)

        return SmartMix(
            title: "Picked For You",
            subtitle: isPremium
                ? "Movies matched to your taste profile"
                : "Train your taste to unlock \(fullCount) personalized picks",
            iconSystemName: "sparkles",
            movies: picks,
            badge: .personalized
        )
    }

    // MARK: - Mood Mix

    private static func buildMoodMix(
        mood: MovieMood,
        movies: [TMDBMovie]
    ) -> SmartMix? {

        let matches = movies.filter { mood.matches(movie: $0) }

        guard matches.count >= 4 else { return nil }

        return SmartMix(
            title: "\(mood.emoji) \(mood.label) Tonight",
            subtitle: "A quick mix tuned to your mood",
            iconSystemName: "wand.and.stars",
            movies: weightedShuffle(matches, limit: 15)
        )
    }

    // MARK: - Weekly Spotlight

    private static func buildWeeklySpotlight(
        movies: [TMDBMovie]
    ) -> SmartMix? {

        let candidates = movies.filter { $0.voteAverage >= 7.5 }

        guard candidates.count >= 5 else { return nil }

        let week = Calendar.current.component(.weekOfYear, from: Date())
        let year = Calendar.current.component(.year, from: Date())

        var rng = SeededGenerator(seed: (year &* 52 &+ week) &* 1_000)

        let picks = Array(candidates.shuffled(using: &rng).prefix(10))

        return SmartMix(
            title: "This Week's Spotlight",
            subtitle: "Refreshes every Monday",
            iconSystemName: "calendar.badge.clock",
            movies: picks,
            badge: .limited
        )
    }

    // MARK: - Comfort Queue

    private static func buildComfortQueue(movies: [TMDBMovie]) -> SmartMix? {

        let candidates = movies.filter {
            MovieMood.cozy.matches(movie: $0) ||
            MovieMood.feelGood.matches(movie: $0)
        }

        guard candidates.count >= 4 else { return nil }

        return SmartMix(
            title: "Comfort Queue",
            subtitle: "Cozy feel-good movies",
            iconSystemName: "sofa.fill",
            movies: weightedShuffle(candidates, limit: 15)
        )
    }

    // MARK: - Thrills

    private static func buildThrillsAndTwists(
        movies: [TMDBMovie]
    ) -> SmartMix? {

        let candidates = movies.filter {
            MovieMood.adrenaline.matches(movie: $0) ||
            MovieMood.mindBend.matches(movie: $0)
        }

        guard candidates.count >= 4 else { return nil }

        return SmartMix(
            title: "Thrills & Twists",
            subtitle: "Action, suspense, and mind-bending plots",
            iconSystemName: "bolt.fill",
            movies: weightedShuffle(candidates, limit: 15),
            badge: .hot
        )
    }

    // MARK: - Date Night

    private static func buildDateNightStack(
        movies: [TMDBMovie]
    ) -> SmartMix? {

        let candidates = movies.filter {
            MovieMood.dateNight.matches(movie: $0)
        }

        guard candidates.count >= 4 else { return nil }

        return SmartMix(
            title: "Date Night Stack",
            subtitle: "Rom-coms and crowd pleasers",
            iconSystemName: "heart.circle.fill",
            movies: weightedShuffle(candidates, limit: 15)
        )
    }

    // MARK: - New Releases

    private static func buildNewReleases(
        movies: [TMDBMovie],
        isPremium: Bool
    ) -> SmartMix? {

        let currentYear = Calendar.current.component(.year, from: Date())

        let recent = movies.filter {
            guard let date = $0.releaseDate,
                  let year = Int(date.prefix(4)) else { return false }

            return year >= currentYear - 2
        }

        guard recent.count >= 4 else { return nil }

        let picks = weightedShuffle(recent, limit: isPremium ? 20 : 6)

        return SmartMix(
            title: "Fresh Off the Reel",
            subtitle: "The newest releases",
            iconSystemName: "sparkles.tv.fill",
            movies: picks,
            badge: .new
        )
    }

    // MARK: - Hidden Gems

    private static func buildHiddenGems(
        movies: [TMDBMovie],
        isPremium: Bool
    ) -> SmartMix? {

        let candidates = movies.filter {
            $0.voteAverage >= 7 &&
            $0.voteCount >= 100 &&
            $0.voteCount <= 2000
        }

        guard candidates.count >= 4 else { return nil }

        let picks = isPremium
            ? weightedShuffle(candidates, limit: 15)
            : Array(candidates.prefix(2))

        return SmartMix(
            title: "Hidden Gems",
            subtitle: "Underrated films most people miss",
            iconSystemName: "diamond.fill",
            movies: picks,
            isPremium: true,
            badge: .exclusive
        )
    }

    // MARK: - Critics Choice

    private static func buildCriticsChoice(
        movies: [TMDBMovie],
        isPremium: Bool
    ) -> SmartMix? {

        let candidates = movies.filter {
            $0.voteAverage >= 8 &&
            $0.voteCount >= 500
        }

        guard candidates.count >= 4 else { return nil }

        let picks = isPremium
            ? weightedShuffle(candidates, limit: 15)
            : Array(candidates.prefix(2))

        return SmartMix(
            title: "Critics' Choice",
            subtitle: "Highest-rated films",
            iconSystemName: "star.fill",
            movies: picks,
            isPremium: true
        )
    }

    // MARK: - Decade Mix

    private static func buildDecadeDive(
        decade: Int,
        movies: [TMDBMovie],
        isPremium: Bool
    ) -> SmartMix? {

        let candidates = movies.filter { decadeOf($0) == decade }

        guard candidates.count >= 4 else { return nil }

        let picks = isPremium
            ? weightedShuffle(candidates, limit: 15)
            : Array(candidates.prefix(3))

        return SmartMix(
            title: "\(decadeLabel(decade)) Classics",
            subtitle: "Films from your favorite era",
            iconSystemName: "clock.fill",
            movies: picks,
            isPremium: true,
            badge: .personalized
        )
    }

    // MARK: - Short Movies

    private static func buildShortAndSweet(
        movies: [TMDBMovie]
    ) -> SmartMix? {

        let genres: Set<Int> = [35,27,16]

        let candidates = movies.filter {
            $0.voteAverage >= 6.5 &&
            genres.intersection($0.genreIDs ?? []).count > 0
        }

        guard candidates.count >= 4 else { return nil }

        return SmartMix(
            title: "Short & Sweet",
            subtitle: "Great picks under 2 hours",
            iconSystemName: "timer",
            movies: weightedShuffle(candidates, limit: 12)
        )
    }

    // MARK: - Hook Mix

    private static func buildMindBlownMix(
        movies: [TMDBMovie]
    ) -> SmartMix? {

        let candidates = movies.filter {
            $0.voteAverage >= 7.5 &&
            ($0.genreIDs ?? []).contains(878)
        }

        guard candidates.count >= 4 else { return nil }

        return SmartMix(
            title: "Mind-Blowing Sci-Fi",
            subtitle: "Movies that melt your brain",
            iconSystemName: "brain.head.profile",
            movies: weightedShuffle(candidates, limit: 12),
            badge: .hot
        )
    }

    // MARK: - Helpers

    private static func weightedShuffle(
        _ list: [TMDBMovie],
        limit: Int
    ) -> [TMDBMovie] {

        let weighted = list.map { movie -> (TMDBMovie, Double) in

            let rating = movie.voteAverage * 1.2
            let popularity = log(Double(movie.voteCount + 1))
            let randomness = Double.random(in: 0...2)

            return (movie, rating + popularity + randomness)
        }

        return weighted
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }

    private static func injectSurprises(
        into movies: [TMDBMovie],
        from pool: [TMDBMovie]
    ) -> [TMDBMovie] {

        var result = movies

        if Double.random(in: 0...1) < 0.25 {
            if let random = pool.randomElement(),
               !result.contains(where: { $0.id == random.id }) {
                result.append(random)
            }
        }

        return result
    }

    private static func removeDuplicateMovies(
        from mixes: [SmartMix]
    ) -> [SmartMix] {

        var seenIDs = Set<Int>()

        return mixes.map { mix in

            let filtered = mix.movies.filter { movie in
                if seenIDs.contains(movie.id) { return false }
                seenIDs.insert(movie.id)
                return true
            }

            return SmartMix(
                title: mix.title,
                subtitle: mix.subtitle,
                iconSystemName: mix.iconSystemName,
                movies: filtered,
                isPremium: mix.isPremium,
                badge: mix.badge,
                engagementHook: mix.engagementHook
            )
        }
    }

    private static func rankMixes(
        _ mixes: [SmartMix]
    ) -> [SmartMix] {

        mixes.sorted {
            $0.movies.count > $1.movies.count
        }
    }

    private static func decadeOf(_ movie: TMDBMovie) -> Int? {

        guard let date = movie.releaseDate,
              let year = Int(date.prefix(4)) else { return nil }

        return (year / 10) * 10
    }

    private static func decadeLabel(_ decade: Int) -> String {

        decade >= 2000
        ? "\(decade)s"
        : "'\(decade % 100)s"
    }
}
