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
    case new         = "NEW"
    case hot         = "HOT"
    case exclusive   = "EXCLUSIVE"
    case limited     = "LIMITED"
    case personalized = "FOR YOU"

    var color: Color {
        switch self {
        case .new:          return .green
        case .hot:          return .orange
        case .exclusive:    return .purple
        case .limited:      return .red
        case .personalized: return .blue
        }
    }
}

// MARK: - Smart Mix Manager

enum SmartMixManager {

    // MARK: - Main Build

    static func buildMixes(
        from movies: [TMDBMovie],
        mood: MovieMood,
        tasteProfile: TasteProfile,
        isPremium: Bool,
        userLevel: UserLevel = .newbie
    ) -> [SmartMix] {
        guard !movies.isEmpty else { return [] }

        var mixes: [SmartMix] = []

        if let personalizedMix = buildPersonalizedMix(
            movies: movies,
            tasteProfile: tasteProfile,
            isPremium: isPremium
        ) {
            mixes.append(personalizedMix)
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

        // FIXED: Proper dedupe using Swift Set
        var seen = Set<String>()
        let deduped = mixes.filter { seen.insert($0.title).inserted }

        return Array(deduped.prefix(8))
    }

    // MARK: - Daily Pick

    static func buildDailyPick(
        from movies: [TMDBMovie],
        tasteProfile: TasteProfile,
        seenMovieIDs: Set<Int>
    ) -> TMDBMovie? {

        let unseen = movies.filter { !seenMovieIDs.contains($0.id) }
        guard !unseen.isEmpty else { return nil }

        let scored = unseen.map { movie -> (movie: TMDBMovie, score: Double) in
            let tasteScore = min(1.0, Double(tasteProfile.score(for: movie)) / 3.0) * 0.6
            let qualityScore = (movie.voteAverage / 10.0) * 0.4
            let popularityBonus = movie.voteCount >= 1000 ? 0.05 : 0.0
            return (movie, tasteScore + qualityScore + popularityBonus)
        }

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        var rng = SeededGenerator(seed: dayOfYear &* 777)

        let topCandidates = scored.sorted { $0.score > $1.score }.prefix(5)
        return topCandidates.randomElement(using: &rng)?.movie
    }

    // MARK: - Challenge Mix

    static func buildChallengeMix(type: ChallengeType, from movies: [TMDBMovie]) -> SmartMix? {

        switch type {

        case .genreExplorer(let genreID, let genreName):

            let candidates = movies.filter { ($0.genreIDs ?? []).contains(genreID) }
            guard candidates.count >= 5 else { return nil }

            return SmartMix(
                title: "\(genreName) Explorer",
                subtitle: "Watch 3 \(genreName.lowercased()) films to complete",
                iconSystemName: "flag.checkered",
                movies: topRated(candidates, limit: 10),
                engagementHook: "Complete for +50 XP"
            )

        case .decadeJourney(let decade):

            let label = decadeLabel(decade)
            let candidates = movies.filter { decadeOf($0) == decade }

            guard candidates.count >= 5 else { return nil }

            return SmartMix(
                title: "\(label) Time Machine",
                subtitle: "Journey through the \(label)",
                iconSystemName: "clock.arrow.circlepath",
                movies: topRated(candidates, limit: 10),
                isPremium: true,
                engagementHook: "Complete for +100 XP"
            )

        case .criticsCircle:

            let candidates = movies.filter { $0.voteAverage >= 8.0 }
            guard candidates.count >= 5 else { return nil }

            return SmartMix(
                title: "Critics' Circle Challenge",
                subtitle: "Watch 5 critically acclaimed films",
                iconSystemName: "star.circle.fill",
                movies: topRated(candidates, limit: 10),
                isPremium: true,
                engagementHook: "Complete for +150 XP"
            )
        }
    }

    // MARK: - Individual Mix Builders

    private static func buildPersonalizedMix(
        movies: [TMDBMovie],
        tasteProfile: TasteProfile,
        isPremium: Bool
    ) -> SmartMix? {

        guard !tasteProfile.topGenreIDs.isEmpty else { return nil }

        let scored = movies
            .map { (movie: $0, score: tasteProfile.score(for: $0)) }
            .filter { $0.score > 0 }
            .sorted {
                $0.score != $1.score
                    ? $0.score > $1.score
                    : $0.movie.voteAverage > $1.movie.voteAverage
            }

        guard !scored.isEmpty else { return nil }

        let fullCount = scored.count
        let limit = isPremium ? min(fullCount, 20) : min(fullCount, 5)
        let picks = Array(scored.prefix(limit)).map { $0.movie }

        return SmartMix(
            title: "Picked For You",
            subtitle: isPremium
                ? "Movies matched to your taste profile"
                : "Train your taste to unlock \(fullCount) personalized picks",
            iconSystemName: "sparkles",
            movies: picks,
            badge: .personalized,
            engagementHook: isPremium || fullCount <= 5
                ? nil
                : "Unlock \(fullCount - 5) more matches with Plus"
        )
    }

    private static func buildMoodMix(mood: MovieMood, movies: [TMDBMovie]) -> SmartMix? {

        let matches = movies.filter { mood.matches(movie: $0) }

        guard matches.count >= 4 else { return nil }

        return SmartMix(
            title: "\(mood.emoji) \(mood.label) Tonight",
            subtitle: "A quick mix tuned to your current mood",
            iconSystemName: "wand.and.stars",
            movies: topRated(matches, limit: 15)
        )
    }

    private static func buildWeeklySpotlight(movies: [TMDBMovie]) -> SmartMix? {

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
            badge: .limited,
            engagementHook: "New picks drop every Monday"
        )
    }

    private static func buildComfortQueue(movies: [TMDBMovie]) -> SmartMix? {

        let candidates = movies.filter {
            MovieMood.cozy.matches(movie: $0) ||
            MovieMood.feelGood.matches(movie: $0)
        }

        guard candidates.count >= 4 else { return nil }

        return SmartMix(
            title: "Comfort Queue",
            subtitle: "Cozy, feel-good picks for a low-key night in",
            iconSystemName: "sofa.fill",
            movies: topRated(candidates, limit: 15)
        )
    }

    private static func buildThrillsAndTwists(movies: [TMDBMovie]) -> SmartMix? {

        let candidates = movies.filter {
            MovieMood.adrenaline.matches(movie: $0) ||
            MovieMood.mindBend.matches(movie: $0)
        }

        guard candidates.count >= 4 else { return nil }

        return SmartMix(
            title: "Thrills & Twists",
            subtitle: "High stakes, big action, and brain-twisting plots",
            iconSystemName: "bolt.fill",
            movies: topRated(candidates, limit: 15),
            badge: .hot
        )
    }

    private static func buildDateNightStack(movies: [TMDBMovie]) -> SmartMix? {

        let candidates = movies.filter {
            MovieMood.dateNight.matches(movie: $0)
        }

        guard candidates.count >= 4 else { return nil }

        return SmartMix(
            title: "Date Night Stack",
            subtitle: "Rom-coms and crowd-pleasers that are easy to agree on",
            iconSystemName: "heart.circle.fill",
            movies: topRated(candidates, limit: 15)
        )
    }

    private static func buildNewReleases(movies: [TMDBMovie], isPremium: Bool) -> SmartMix? {

        let currentYear = Calendar.current.component(.year, from: Date())

        let recent = movies
            .filter {
                guard let date = $0.releaseDate,
                      let year = Int(date.prefix(4)) else { return false }

                return year >= currentYear - 2
            }
            .sorted { ($0.releaseDate ?? "") > ($1.releaseDate ?? "") }

        guard recent.count >= 4 else { return nil }

        let freeLimit = 6
        let picks = isPremium
            ? Array(recent.prefix(20))
            : Array(recent.prefix(freeLimit))

        return SmartMix(
            title: "Fresh Off the Reel",
            subtitle: isPremium
                ? "The newest releases hitting screens now"
                : "Showing \(freeLimit) of \(recent.count) new releases",
            iconSystemName: "sparkles.tv.fill",
            movies: picks,
            badge: .new,
            engagementHook: isPremium
                ? nil
                : "Unlock all \(recent.count) new releases with Plus"
        )
    }

    private static func buildHiddenGems(movies: [TMDBMovie], isPremium: Bool) -> SmartMix? {

        let candidates = movies.filter {
            $0.voteAverage >= 7.0 &&
            $0.voteCount >= 100 &&
            $0.voteCount <= 2000
        }

        guard candidates.count >= 4 else { return nil }

        return SmartMix(
            title: "Hidden Gems",
            subtitle: isPremium
                ? "Underrated films most people haven't discovered"
                : "Exclusive access with FilmFuel+",
            iconSystemName: "diamond.fill",
            movies: isPremium
                ? topRated(candidates, limit: 15)
                : Array(candidates.prefix(2)),
            isPremium: true,
            badge: .exclusive,
            engagementHook: isPremium
                ? nil
                : "Unlock \(candidates.count) hidden gems with Plus"
        )
    }

    private static func buildCriticsChoice(movies: [TMDBMovie], isPremium: Bool) -> SmartMix? {

        let candidates = movies.filter {
            $0.voteAverage >= 8.0 &&
            $0.voteCount >= 500
        }

        guard candidates.count >= 4 else { return nil }

        return SmartMix(
            title: "Critics' Choice",
            subtitle: isPremium
                ? "Only the highest-rated films make the cut"
                : "Premium collection for FilmFuel+ members",
            iconSystemName: "star.fill",
            movies: isPremium
                ? topRated(candidates, limit: 15)
                : Array(candidates.prefix(2)),
            isPremium: true,
            engagementHook: isPremium
                ? nil
                : "See all \(candidates.count) top-rated picks with Plus"
        )
    }

    private static func buildDecadeDive(
        decade: Int,
        movies: [TMDBMovie],
        isPremium: Bool
    ) -> SmartMix? {

        let candidates = movies.filter { decadeOf($0) == decade }

        guard candidates.count >= 4 else { return nil }

        let label = decadeLabel(decade)

        return SmartMix(
            title: "\(label) Classics",
            subtitle: isPremium
                ? "Your favorite era, curated"
                : "Unlock decade collections with Plus",
            iconSystemName: "clock.fill",
            movies: isPremium
                ? topRated(candidates, limit: 15)
                : Array(candidates.prefix(3)),
            isPremium: true,
            badge: .personalized,
            engagementHook: isPremium
                ? nil
                : "Explore the \(label) with Plus"
        )
    }

    private static func buildShortAndSweet(movies: [TMDBMovie]) -> SmartMix? {

        let shortGenres: Set<Int> = [35, 27, 16, 10770]

        let candidates = movies.filter {
            $0.voteAverage >= 6.5 &&
            shortGenres.intersection($0.genreIDs ?? []).count > 0
        }

        guard candidates.count >= 4 else { return nil }

        return SmartMix(
            title: "Short & Sweet",
            subtitle: "Great picks for when you have less than 2 hours",
            iconSystemName: "timer",
            movies: topRated(candidates, limit: 12)
        )
    }

    // MARK: - Shared Helpers

    private static func topRated(_ list: [TMDBMovie], limit: Int) -> [TMDBMovie] {

        Array(
            list.sorted {
                $0.voteAverage != $1.voteAverage
                    ? $0.voteAverage > $1.voteAverage
                    : $0.voteCount > $1.voteCount
            }
            .prefix(limit)
        )
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

// MARK: - Challenge Types

enum ChallengeType {
    case genreExplorer(genreID: Int, genreName: String)
    case decadeJourney(decade: Int)
    case criticsCircle
}
