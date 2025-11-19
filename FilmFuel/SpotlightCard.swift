//
//  SpotlightCard.swift
//  FilmFuel
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SpotlightCard: View {
    let quote: Quote
    let meta: MovieMeta?

    @Environment(\.openURL) private var openURL

    private var displayTitle: String {
        meta?.title ?? quote.movie
    }

    /// Prefer JSON fun fact if present, otherwise a small hook line.
    private var funFactText: String {
        let raw = (quote.funFact ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty {
            return raw
        }
        return "Today’s spotlight pick – tap into the vibe and then dive into more quotes below."
    }

    private var imdbURL: URL? {
        if let id = meta?.imdbID, !id.isEmpty {
            return URL(string: "https://www.imdb.com/title/\(id)/")
        }
        let query = "\(displayTitle) \(quote.year)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "https://www.imdb.com/find/?q=\(encoded)&s=tt")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top label
            Label("Today’s Spotlight", systemImage: "sun.max.fill")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.25))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(displayTitle)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(String(quote.year))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text("“\(quote.text)”")
                .font(.headline)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.9)

            Text(funFactText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if let url = imdbURL {
                    Button {
                        openURL(url)
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                    } label: {
                        HStack(spacing: 6) {
                            Text("View on IMDb")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(red: 245/255, green: 197/255, blue: 24/255))
                        )
                        .foregroundStyle(Color.black)
                    }
                }

                Spacer()
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.14, blue: 0.30),
                            Color(red: 0.10, green: 0.06, blue: 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(radius: 10, y: 6)
        )
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
    }
}
