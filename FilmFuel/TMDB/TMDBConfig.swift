//
//  Untitled.swift
//  FilmFuel
//
//  Created by Chris Olah on 11/22/25.
//

import Foundation

enum TMDBConfig {
    // TODO: Put your real TMDB API key here
    static let apiKey = "5b108373b3820fb6f6ccc6a0fba551b6"

    static let baseURL = URL(string: "https://api.themoviedb.org/3")!

    // Image base (you can tweak size; w500 is good for posters)
    static let imageBaseURL = URL(string: "https://image.tmdb.org/t/p/w500")!
}
