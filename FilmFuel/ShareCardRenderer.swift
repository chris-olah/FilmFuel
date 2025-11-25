//  ShareCardRenderer.swift
//  FilmFuel
//
//  Helper to render a shareable image for a movie.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
struct MovieShareCardView: View {
    let movie: TMDBMovie

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop
            Group {
                if let url = movie.backdropURL ?? movie.posterURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Color(.secondarySystemBackground)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Color(.secondarySystemBackground)
                        @unknown default:
                            Color(.secondarySystemBackground)
                        }
                    }
                } else {
                    Color(.secondarySystemBackground)
                }
            }
            .clipped()

            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(movie.title)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if movie.yearText != "—" {
                        Text(movie.yearText)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                    }

                    Label(
                        String(format: "%.1f", movie.voteAverage),
                        systemImage: "star.fill"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Capsule())
                }

                Text("From FilmFuel Discover")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 4)
            }
            .padding(16)
        }
        .frame(width: 600, height: 315) // 16:9-ish share card
        .background(Color.black)
    }
}

enum ShareCardRenderer {
    static func image(for movie: TMDBMovie) -> UIImage? {
        let view = MovieShareCardView(movie: movie)
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
#endif
