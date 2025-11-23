//
//  MovieDetailVM.swift
//  FilmFuel
//
//  Created by Chris Olah on 11/22/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class MovieDetailVM: ObservableObject {
    @Published private(set) var detail: TMDBMovieDetail?
    @Published private(set) var recommendations: [TMDBMovie] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client: TMDBClientProtocol
    private let baseMovie: TMDBMovie

    init(movie: TMDBMovie, client: TMDBClientProtocol) {
        self.baseMovie = movie
        self.client = client
    }

    func load() {
        Task { [weak self] in
            await self?.loadInternal()
        }
    }

    private func loadInternal() async {
        isLoading = true
        errorMessage = nil

        do {
            async let detailTask = client.fetchMovieDetail(id: baseMovie.id)
            async let recsTask   = client.fetchMovieRecommendations(id: baseMovie.id, page: 1)

            let (detail, recsPage) = try await (detailTask, recsTask)

            self.detail = detail

            // Reuse your quality filter logic: poster + votes
            let filteredRecs = recsPage.results.filter { m in
                m.posterPath != nil && m.voteCount >= 20
            }
            self.recommendations = filteredRecs
        } catch {
            errorMessage = "Could not load details. Please try again."
            print("MovieDetail error:", error)
        }

        isLoading = false
    }
}
