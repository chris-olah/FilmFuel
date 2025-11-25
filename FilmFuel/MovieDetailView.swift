//
//  MovieDetailView.swift
//  FilmFuel
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct MovieDetailView: View {
    let movie: TMDBMovie
    private let client: TMDBClientProtocol

    // Core detail
    @State private var detail: TMDBMovieDetail?
    @State private var certification: String?
    @State private var usWatchRegion: TMDBWatchProvidersRegion?

    // More like this
    @State private var recommendations: [TMDBMovie] = []

    // Loading / error
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(
        movie: TMDBMovie,
        client: TMDBClientProtocol = TMDBClient()
    ) {
        self.movie = movie
        self.client = client
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerImageSection

                VStack(alignment: .leading, spacing: 16) {
                    titleSection
                    metaChipsSection
                    taglineSection
                    overviewSection
                    genresSection
                    whereToWatchSection
                    ratingsSection
                    moreLikeThisSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(detail?.title ?? movie.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetailsIfNeeded()
        }
        .overlay(alignment: .center) {
            if isLoading && detail == nil && errorMessage == nil {
                ProgressView()
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .alert("Couldn’t load movie details", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Sections

    private var headerImageSection: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let url = detail?.backdropURL
                    ?? detail?.posterURL
                    ?? movie.backdropURL
                    ?? movie.posterURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(.secondarySystemBackground),
                                            Color(.tertiarySystemBackground)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay {
                                    ProgressView()
                                }

                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()

                        case .failure:
                            placeholderImage

                        @unknown default:
                            placeholderImage
                        }
                    }
                } else {
                    placeholderImage
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16/9, contentMode: .fit)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.75)
                    ],
                    startPoint: .center,
                    endPoint: .bottom
                )
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(detail?.title ?? movie.title)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .shadow(radius: 10)

                HStack(spacing: 8) {
                    let year = detail?.yearText ?? movie.yearText
                    if year != "—" {
                        Text(year)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.18))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }

                    if let cert = certification, !cert.isEmpty {
                        Text(cert)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.18))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(detail?.title ?? movie.title)
                .font(.title3.weight(.semibold))

            if let tagline = detail?.tagline,
               !tagline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(tagline)
                    .font(.subheadline.italic())
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var metaChipsSection: some View {
        HStack(spacing: 8) {
            // Rating chip
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                Text(String(format: "%.1f", detail?.voteAverage ?? movie.voteAverage))
            }
            .font(.caption.weight(.medium))
            .foregroundColor(.yellow)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemYellow).opacity(0.15))
            .clipShape(Capsule())

            // Runtime chip
            if let runtimeText = detail?.runtimeText, runtimeText != "—" {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(runtimeText)
                }
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }

            // Vote count
            let votes = detail?.voteCount ?? movie.voteCount
            if votes > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill")
                    Text("\(votes) ratings")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }

            Spacer()
        }
    }

    private var taglineSection: some View {
        EmptyView()
    }

    private var overviewSection: some View {
        Group {
            if let fullOverview = detail?.overview,
               !fullOverview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overview")
                        .font(.headline)
                    Text(fullOverview)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if !movie.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overview")
                        .font(.headline)
                    Text(movie.overview)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var genresSection: some View {
        Group {
            if let genres = detail?.genres, !genres.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Genres")
                        .font(.headline)

                    FlexibleGenreChips(genres: genres)
                }
            }
        }
    }

    private var whereToWatchSection: some View {
        Group {
            if let region = usWatchRegion,
               let names = region.flatrateNamesJoined.isEmpty ? nil : region.flatrateNamesJoined {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Where to watch")
                        .font(.headline)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "tv")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(names)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let link = region.link, let url = URL(string: link) {
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                Text("Open on TMDB")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                    }
                }
            } else if detail != nil {
                // Only show this fallback once we actually have detail
                VStack(alignment: .leading, spacing: 4) {
                    Text("Where to watch")
                        .font(.headline)
                    Text("Streaming availability may vary by region.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var ratingsSection: some View {
        Group {
            if let cert = certification, !cert.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rating")
                        .font(.headline)
                    Text("Rated \(cert) (US)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var moreLikeThisSection: some View {
        Group {
            if !recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("More like this")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(recommendations) { rec in
                                NavigationLink {
                                    MovieDetailView(movie: rec, client: client)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        AsyncImage(url: rec.posterURL) { phase in
                                            switch phase {
                                            case .empty:
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(Color(.secondarySystemBackground))
                                                    .frame(width: 110, height: 165)
                                                    .overlay {
                                                        ProgressView()
                                                    }

                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 110, height: 165)
                                                    .clipped()
                                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                            case .failure:
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(Color(.secondarySystemBackground))
                                                    .frame(width: 110, height: 165)
                                                    .overlay {
                                                        Image(systemName: "film")
                                                            .foregroundColor(.secondary)
                                                    }

                                            @unknown default:
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(Color(.secondarySystemBackground))
                                                    .frame(width: 110, height: 165)
                                            }
                                        }

                                        Text(rec.title)
                                            .font(.caption)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                            .frame(width: 110, alignment: .leading)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var placeholderImage: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.secondarySystemBackground),
                    Color(.tertiarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "film")
                .font(.largeTitle)
                .foregroundColor(.secondary)
        }
    }

    @MainActor
    private func loadDetailsIfNeeded() async {
        guard detail == nil, !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            async let d = client.fetchMovieDetail(id: movie.id)
            async let providersResp = client.fetchWatchProviders(id: movie.id)
            async let rd = client.fetchReleaseDates(id: movie.id)
            async let recResp = client.fetchMovieRecommendations(id: movie.id, page: 1)

            let (detail, providers, releaseDates, recList) = try await (d, providersResp, rd, recResp)

            self.detail = detail
            self.usWatchRegion = providers.region("US")
            self.certification = releaseDates.primaryCertification(forRegion: "US")

            // Basic filter: posters only, not the same movie
            self.recommendations = recList.results
                .filter { $0.posterPath != nil && $0.id != movie.id }

        } catch {
            print("❌ Movie detail fetch failed: \(error)")
            errorMessage = "Please check your connection and try again."
        }

        isLoading = false
    }
}

// MARK: - Flexible Genre Chips

/// Simple flow layout for genre chips (no external deps)
private struct FlexibleGenreChips: View {
    let genres: [TMDBGenre]

    var body: some View {
        FlexibleChipsLayout {
            ForEach(genres) { genre in
                Text(genre.name)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
            }
        }
    }
}

/// Generic flexible chips layout using alignment-guided stacks
private struct FlexibleChipsLayout<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        FlowLayout(
            alignment: .leading,
            spacing: 8,
            rowSpacing: 8,
            content: content
        )
    }
}

/// Very lightweight flow layout for small chip views
private struct FlowLayout<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let rowSpacing: CGFloat
    @ViewBuilder var content: () -> Content

    init(
        alignment: HorizontalAlignment = .leading,
        spacing: CGFloat = 8,
        rowSpacing: CGFloat = 8,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.rowSpacing = rowSpacing
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            self.generateContent(in: width)
        }
        .frame(minHeight: 0)
    }

    private func generateContent(in width: CGFloat) -> some View {
        var rows: [[AnyView]] = [[]]
        var currentRowWidth: CGFloat = 0

        // Measure each chip
        let chips = content().asArray()

        for chip in chips {
            let chipWidth = chip.intrinsicWidth() + spacing

            if currentRowWidth + chipWidth > width, !rows.last!.isEmpty {
                rows.append([chip])
                currentRowWidth = chipWidth
            } else {
                rows[rows.count - 1].append(chip)
                currentRowWidth += chipWidth
            }
        }

        return VStack(alignment: alignment, spacing: rowSpacing) {
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: spacing) {
                    ForEach(0..<rows[rowIndex].count, id: \.self) { chipIndex in
                        rows[rowIndex][chipIndex]
                    }
                }
            }
        }
    }
}

// Tiny helpers to make FlowLayout work
private extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }

    func intrinsicWidth() -> CGFloat {
        let controller = UIHostingController(rootView: self)
        return controller.view.intrinsicContentSize.width
    }

    func asArray() -> [AnyView] {
        // This treats the whole content as a single chip; for small # of genres
        // this is fine, but you can expand later if you want per-chip measurement.
        [self.eraseToAnyView()]
    }
}
