//
//  SmartMixManager.swift
//  FilmFuel
//
//  Curated movie mixes with premium gates and engagement optimization
//

import Foundation

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
    case new = "NEW"
    case hot = "HOT"
    case exclusive = "EXCLUSIVE"
    case limited = "LIMITED"
    case personalized = "FOR YOU"
    
    var color: String {
        switch self {
        case .new:         return "green"
        case .hot:         return "orange"
        case .exclusive:   return "purple"
        case .limited:     return "red"
        case .personalized: return "blue"
        }
    }
}

// MARK: - Smart Mix Manager

enum SmartMixManager {
    
    /// Builds curated mixes from the current feed with premium gates and engagement hooks
    static func buildMixes(
        from movies: [TMDBMovie],
        mood: MovieMood,
        tasteProfile: TasteProfile,
        isPremium: Bool,
        userLevel: UserLevel = .newbie
    ) -> [SmartMix] {
        guard !movies.isEmpty else { return [] }
        
        var mixes: [SmartMix] = []
        
        // Helper functions
        func topRated(_ list: [TMDBMovie], limit: Int) -> [TMDBMovie] {
            Array(list.sorted { lhs, rhs in
                if lhs.voteAverage == rhs.voteAverage {
                    return lhs.voteCount > rhs.voteCount
                }
                return lhs.voteAverage > rhs.voteAverage
            }.prefix(limit))
        }
        
        func recentlyReleased(_ list: [TMDBMovie], limit: Int) -> [TMDBMovie] {
            list.filter { movie in
                guard let date = movie.releaseDate,
                      let year = Int(date.prefix(4)) else { return false }
                let currentYear = Calendar.current.component(.year, from: Date())
                return year >= currentYear - 2
            }
            .sorted { ($0.releaseDate ?? "") > ($1.releaseDate ?? "") }
            .prefix(limit)
            .map { $0 }
        }
        
        // 1. PERSONALIZED: From Your Taste (Premium teaser for free users)
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
                
                // Free users see limited picks, premium gets full access
                let limit = isPremium ? 20 : 5
                let picks = Array(sorted.prefix(limit)).map { $0.movie }
                
                mixes.append(
                    SmartMix(
                        title: "Picked For You",
                        subtitle: isPremium
                            ? "Movies matched to your unique taste profile"
                            : "Upgrade to see all \(filtered.count) personalized picks",
                        iconSystemName: "sparkles",
                        movies: picks,
                        isPremium: false, // Show to everyone but limit content
                        badge: .personalized,
                        engagementHook: isPremium ? nil : "Unlock \(filtered.count - 5) more matches with Plus"
                    )
                )
            }
        }
        
        // 2. Comfort Queue (cozy / feel-good) - FREE
        let comfortCandidates = movies.filter { m in
            MovieMood.cozy.matches(movie: m) || MovieMood.feelGood.matches(movie: m)
        }
        if comfortCandidates.count >= 4 {
            mixes.append(
                SmartMix(
                    title: "Comfort Queue",
                    subtitle: "Cozy, feel-good picks for a low-key night in",
                    iconSystemName: "sofa.fill",
                    movies: topRated(comfortCandidates, limit: 15),
                    isPremium: false,
                    badge: nil,
                    engagementHook: nil
                )
            )
        }
        
        // 3. Thrills & Twists - FREE
        let thrillCandidates = movies.filter { m in
            MovieMood.adrenaline.matches(movie: m) || MovieMood.mindBend.matches(movie: m)
        }
        if thrillCandidates.count >= 4 {
            mixes.append(
                SmartMix(
                    title: "Thrills & Twists",
                    subtitle: "High stakes, big action, and brain-twisting plots",
                    iconSystemName: "bolt.fill",
                    movies: topRated(thrillCandidates, limit: 15),
                    isPremium: false,
                    badge: .hot,
                    engagementHook: nil
                )
            )
        }
        
        // 4. Date Night Stack - FREE
        let dateCandidates = movies.filter { m in
            MovieMood.dateNight.matches(movie: m)
        }
        if dateCandidates.count >= 4 {
            mixes.append(
                SmartMix(
                    title: "Date Night Stack",
                    subtitle: "Rom-coms and crowd-pleasers that are easy to agree on",
                    iconSystemName: "heart.circle.fill",
                    movies: topRated(dateCandidates, limit: 15),
                    isPremium: false,
                    badge: nil,
                    engagementHook: nil
                )
            )
        }
        
        // 5. Hidden Gems - PREMIUM
        let gemCandidates = movies.filter { m in
            m.voteAverage >= 7.0 && m.voteCount >= 50 && m.voteCount <= 1000
        }
        if gemCandidates.count >= 4 {
            mixes.append(
                SmartMix(
                    title: "Hidden Gems",
                    subtitle: isPremium
                        ? "Underrated films with cult potential"
                        : "Exclusive access with FilmFuel+",
                    iconSystemName: "diamond.fill",
                    movies: isPremium ? topRated(gemCandidates, limit: 15) : Array(gemCandidates.prefix(2)),
                    isPremium: true,
                    badge: .exclusive,
                    engagementHook: isPremium ? nil : "Unlock \(gemCandidates.count) hidden gems"
                )
            )
        }
        
        // 6. Critics' Choice - PREMIUM
        let criticsCandidates = movies.filter { $0.voteAverage >= 8.0 }
        if criticsCandidates.count >= 4 {
            mixes.append(
                SmartMix(
                    title: "Critics' Choice",
                    subtitle: isPremium
                        ? "Only the highest-rated films make the cut"
                        : "Premium collection for FilmFuel+ members",
                    iconSystemName: "star.fill",
                    movies: isPremium ? topRated(criticsCandidates, limit: 15) : Array(criticsCandidates.prefix(2)),
                    isPremium: true,
                    badge: nil,
                    engagementHook: isPremium ? nil : "See all \(criticsCandidates.count) top-rated picks"
                )
            )
        }
        
        // 7. New Releases - LIMITED FREE (teaser)
        let newReleases = recentlyReleased(movies, limit: 20)
        if newReleases.count >= 4 {
            let freeLimit = 6
            mixes.append(
                SmartMix(
                    title: "Fresh Off the Reel",
                    subtitle: isPremium
                        ? "The newest releases hitting screens now"
                        : "See \(freeLimit) of \(newReleases.count) new releases",
                    iconSystemName: "sparkles.tv.fill",
                    movies: isPremium ? newReleases : Array(newReleases.prefix(freeLimit)),
                    isPremium: false,
                    badge: .new,
                    engagementHook: isPremium ? nil : "Unlock all \(newReleases.count) new releases"
                )
            )
        }
        
        // 8. Mood Match (current mood) - FREE
        if mood != .any {
            let moodMatches = movies.filter { mood.matches(movie: $0) }
            if moodMatches.count >= 4 {
                mixes.append(
                    SmartMix(
                        title: "\(mood.label) Tonight",
                        subtitle: "A quick mix tuned to your current mood",
                        iconSystemName: "wand.and.stars",
                        movies: topRated(moodMatches, limit: 15),
                        isPremium: false,
                        badge: nil,
                        engagementHook: nil
                    )
                )
            }
        }
        
        // 9. Decade Dive (if user has decade preference) - PREMIUM
        if let decade = tasteProfile.favoriteDecade {
            let decadeCandidates = movies.filter { movie in
                guard let date = movie.releaseDate,
                      let year = Int(date.prefix(4)) else { return false }
                let movieDecade = (year / 10) * 10
                return movieDecade == decade
            }
            
            if decadeCandidates.count >= 4 {
                let decadeLabel = decade >= 2000 ? "\(decade)s" : "\(decade % 100)s"
                mixes.append(
                    SmartMix(
                        title: "\(decadeLabel) Classics",
                        subtitle: isPremium
                            ? "Your favorite era, curated"
                            : "Unlock decade collections with Plus",
                        iconSystemName: "clock.fill",
                        movies: isPremium ? topRated(decadeCandidates, limit: 15) : Array(decadeCandidates.prefix(3)),
                        isPremium: true,
                        badge: .personalized,
                        engagementHook: isPremium ? nil : "Explore the \(decadeLabel) with Plus"
                    )
                )
            }
        }
        
        // 10. Weekly Spotlight - LIMITED TIME (creates urgency)
        let spotlightCandidates = movies.filter { $0.voteAverage >= 7.5 }
        if spotlightCandidates.count >= 5 {
            // Seed with current week for consistent "weekly" picks
            let weekNumber = Calendar.current.component(.weekOfYear, from: Date())
            var rng = SeededGenerator(seed: weekNumber * 1000)
            let shuffled = spotlightCandidates.shuffled(using: &rng)
            
            mixes.append(
                SmartMix(
                    title: "This Week's Spotlight",
                    subtitle: "Refreshes every week – catch them while you can",
                    iconSystemName: "calendar.badge.clock",
                    movies: Array(shuffled.prefix(10)),
                    isPremium: false,
                    badge: .limited,
                    engagementHook: "New picks drop every Monday"
                )
            )
        }
        
        // Sort mixes: Personalized first, then premium teasers, then free
        let sortedMixes = mixes.sorted { lhs, rhs in
            // Personalized always first
            if lhs.badge == .personalized && rhs.badge != .personalized { return true }
            if rhs.badge == .personalized && lhs.badge != .personalized { return false }
            
            // Then premium teasers (to show value)
            if lhs.isPremium && !isPremium && !rhs.isPremium { return true }
            if rhs.isPremium && !isPremium && !lhs.isPremium { return false }
            
            return false
        }
        
        // Cap at 6 mixes to avoid overwhelming
        return Array(sortedMixes.prefix(6))
    }
    
    /// Builds a single "Daily Pick" mix - one highly curated recommendation
    static func buildDailyPick(
        from movies: [TMDBMovie],
        tasteProfile: TasteProfile,
        seenMovieIDs: Set<Int>
    ) -> TMDBMovie? {
        // Filter out seen movies
        let unseen = movies.filter { !seenMovieIDs.contains($0.id) }
        guard !unseen.isEmpty else { return nil }
        
        // Score by taste + quality
        let scored = unseen.map { movie -> (movie: TMDBMovie, score: Double) in
            let tasteScore = Double(tasteProfile.score(for: movie)) * 10
            let qualityScore = movie.voteAverage
            let popularityBonus = movie.voteCount >= 1000 ? 2.0 : 0
            return (movie, tasteScore + qualityScore + popularityBonus)
        }
        
        // Seed with today's date for consistent daily pick
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        var rng = SeededGenerator(seed: dayOfYear * 777)
        
        // Pick from top 5 candidates for some variety
        let topCandidates = scored.sorted { $0.score > $1.score }.prefix(5)
        return topCandidates.randomElement(using: &rng)?.movie
    }
    
    /// Builds challenge/quest-style mixes for gamification
    static func buildChallengeMix(
        type: ChallengeType,
        from movies: [TMDBMovie]
    ) -> SmartMix? {
        switch type {
        case .genreExplorer(let genreID, let genreName):
            let candidates = movies.filter { ($0.genreIDs ?? []).contains(genreID) }
            guard candidates.count >= 5 else { return nil }
            
            return SmartMix(
                title: "\(genreName) Explorer",
                subtitle: "Watch 3 \(genreName.lowercased()) films to complete",
                iconSystemName: "flag.checkered",
                movies: Array(candidates.prefix(10)),
                isPremium: false,
                badge: nil,
                engagementHook: "Complete for +50 XP"
            )
            
        case .decadeJourney(let decade):
            let decadeLabel = decade >= 2000 ? "\(decade)s" : "\(decade % 100)s"
            let candidates = movies.filter { movie in
                guard let date = movie.releaseDate,
                      let year = Int(date.prefix(4)) else { return false }
                return (year / 10) * 10 == decade
            }
            guard candidates.count >= 5 else { return nil }
            
            return SmartMix(
                title: "\(decadeLabel) Time Machine",
                subtitle: "Journey through the \(decadeLabel)",
                iconSystemName: "clock.arrow.circlepath",
                movies: Array(candidates.prefix(10)),
                isPremium: true,
                badge: nil,
                engagementHook: "Complete for +100 XP"
            )
            
        case .criticsCircle:
            let candidates = movies.filter { $0.voteAverage >= 8.0 }
            guard candidates.count >= 5 else { return nil }
            
            return SmartMix(
                title: "Critics' Circle Challenge",
                subtitle: "Watch 5 critically acclaimed films",
                iconSystemName: "star.circle.fill",
                movies: Array(candidates.prefix(10)),
                isPremium: true,
                badge: nil,
                engagementHook: "Complete for +150 XP"
            )
        }
    }
}

// MARK: - Challenge Types

enum ChallengeType {
    case genreExplorer(genreID: Int, genreName: String)
    case decadeJourney(decade: Int)
    case criticsCircle
}
