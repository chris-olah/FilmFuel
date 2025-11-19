//
//  FunFactCard.swift
//  FilmFuel
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FunFactCard: View {
    let quote: Quote
    let meta: MovieMeta?
    var onShare: () -> Void

    @Environment(\.openURL) private var openURL

    private var displayTitle: String {
        meta?.title ?? quote.movie
    }

    /// Prefer JSON fun fact, then OMDb fun fact, then fallback line.
    private var funFactText: String {
        let fromJSON = (quote.funFact ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !fromJSON.isEmpty {
            return fromJSON
        }

        let fromMeta = meta?.funFact.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromMeta.isEmpty {
            return fromMeta
        }

        return "Swipe into the archive – this movie has some wild behind-the-scenes stories."
    }

    private var yearText: String {
        String(quote.year)
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
        VStack(alignment: .leading, spacing: 10) {
            // Header: label + movie
            HStack {
                Label("Archive Fun Fact", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.18))
                    )

                Spacer()

                Text(yearText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text("“\(quote.text)”")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }

            Text(funFactText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)

            HStack(spacing: 12) {
                Button {
                    onShare()
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(.tertiarySystemBackground))
                        )
                }

                if let url = imdbURL {
                    Button {
                        openURL(url)
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                    } label: {
                        Label("IMDb", systemImage: "arrow.up.right.square")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(.tertiarySystemBackground))
                            )
                    }
                }

                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.secondarySystemBackground),
                            Color(.secondarySystemBackground).opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(radius: 6, y: 3)
        )
        .padding(.horizontal, 20)
    }
}
