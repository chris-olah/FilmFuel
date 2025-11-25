//
//  SmartMixManager.swift
//  FilmFuel
//

import Foundation

struct SmartMix: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let iconSystemName: String
    let movies: [TMDBMovie]
}

enum SmartMixManager {
    /// Builds a small set of curated "mixes" from the current feed,
    /// using mood + taste profile to pick subsets.
    static func buildMixes(
        from movies: [TMDBMovie],
        mood: MovieMood,
        tasteProfile: TasteProfile
    ) -> [SmartMix] {
        guard !movies.isEmpty else { return [] }

        var mixes: [SmartMix] = []

        // Helper: apply min count + sort
        func topRated(_ list: [TMDBMovie], limit: Int) -> [TMDBMovie] {
            Array(list.sorted(by: { lhs, rhs in
                if lhs.voteAverage == rhs.voteAverage {
                    return lhs.voteCount > rhs.voteCount
                }
                return lhs.voteAverage > rhs.voteAverage
            }).prefix(limit))
        }

        // 1. Comfort Queue (cozy / feel-good)
        let comfortCandidates = movies.filter { m in
            MovieMood.cozy.matches(movie: m) || MovieMood.feelGood.matches(movie: m)
        }
        if comfortCandidates.count >= 4 {
            mixes.append(
                SmartMix(
                    title: "Comfort Queue",
                    subtitle: "Cozy, feel-good picks for a low-key night in.",
                    iconSystemName: "sofa.fill",
                    movies: topRated(comfortCandidates, limit: 15)
                )
            )
        }

        // 2. Thrills & Twists (adrenaline + mind-bend)
        let thrillCandidates = movies.filter { m in
            MovieMood.adrenaline.matches(movie: m) || MovieMood.mindBend.matches(movie: m)
        }
        if thrillCandidates.count >= 4 {
            mixes.append(
                SmartMix(
                    title: "Thrills & Twists",
                    subtitle: "High stakes, big action, and brain-twisting plots.",
                    iconSystemName: "bolt.fill",
                    movies: topRated(thrillCandidates, limit: 15)
                )
            )
        }

        // 3. Date Night Stack (romance / comedy)
        let dateCandidates = movies.filter { m in
            MovieMood.dateNight.matches(movie: m)
        }
        if dateCandidates.count >= 4 {
            mixes.append(
                SmartMix(
                    title: "Date Night Stack",
                    subtitle: "Rom-coms and crowd-pleasers that are easy to agree on.",
                    iconSystemName: "heart.circle.fill",
                    movies: topRated(dateCandidates, limit: 15)
                )
            )
        }

        // 4. From Your Taste (if we have any taste data)
        if !tasteProfile.topGenreIDs.isEmpty {
            let scored = movies.map { m -> (movie: TMDBMovie, score: Int) in
                (m, tasteProfile.score(for: m))
            }
            let filtered = scored.filter { $0.score > 0 }
            if !filtered.isEmpty {
                let sorted = filtered.sorted { lhs, rhs in
                    if lhs.score == rhs.score {
                        return lhs.movie.voteAverage > rhs.movie.voteAverage
                    }
                    return lhs.score > rhs.score
                }
                let picks = Array(sorted.prefix(20)).map { $0.movie }
                mixes.append(
                    SmartMix(
                        title: "From Your Taste",
                        subtitle: "Movies picked from the genres you keep gravitating toward.",
                        iconSystemName: "sparkles",
                        movies: picks
                    )
                )
            }
        }

        // 5. Mood Boost (tie directly to the currently selected mood)
        if mood != .any {
            let moodMatches = movies.filter { mood.matches(movie: $0) }
            if moodMatches.count >= 4 {
                mixes.append(
                    SmartMix(
                        title: "\(mood.label) Tonight",
                        subtitle: "A quick mix tuned to your current mood filter.",
                        iconSystemName: "wand.and.stars",
                        movies: topRated(moodMatches, limit: 15)
                    )
                )
            }
        }

        // Cap at 3–4 mixes to avoid overwhelming
        if mixes.count > 4 {
            return Array(mixes.prefix(4))
        }
        return mixes
    }
}
