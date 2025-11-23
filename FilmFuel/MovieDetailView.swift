import SwiftUI

struct MovieDetailView: View {
    @StateObject private var vm: MovieDetailVM
    private let baseMovie: TMDBMovie

    init(movie: TMDBMovie, client: TMDBClientProtocol = TMDBClient()) {
        self.baseMovie = movie
        _vm = StateObject(wrappedValue: MovieDetailVM(movie: movie, client: client))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerImage
                titleBlock
                metaRow
                overviewSection
                if !vm.recommendations.isEmpty {
                    recommendationsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle(baseMovie.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.load()
        }
    }

    // MARK: - Sections

    private var headerImage: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let path = vm.detail?.backdropPath ?? baseMovie.backdropPath,
                   let url = URL(string: "https://image.tmdb.org/t/p/w780\(path)") {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle().overlay { ProgressView() }
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            placeholder
                        @unknown default:
                            placeholder
                        }
                    }
                } else if let url = baseMovie.posterURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle().overlay { ProgressView() }
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            placeholder
                        @unknown default:
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            )

            VStack(alignment: .leading, spacing: 4) {
                let tagline = vm.detail?.tagline
                Text((tagline?.isEmpty == false ? tagline : nil) ?? baseMovie.title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                    .lineLimit(2)
            }
            .padding()
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(radius: 10, y: 6)
        .padding(.top, 12)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(vm.detail?.title ?? baseMovie.title)
                .font(.title3.weight(.semibold))

            HStack(spacing: 8) {
                let yearText = vm.detail?.yearText ?? baseMovie.yearText
                if yearText != "—" {
                    Text(yearText)
                }

                if let runtime = vm.detail?.runtimeText, runtime != "—" {
                    Text("• \(runtime)")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            if let genres = vm.detail?.genres, !genres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(genres) { genre in
                            Text(genre.name)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: 12) {
            Label(
                String(format: "%.1f", vm.detail?.voteAverage ?? baseMovie.voteAverage),
                systemImage: "star.fill"
            )
            .foregroundColor(.yellow)

            let count = vm.detail?.voteCount ?? baseMovie.voteCount
            if count > 0 {
                Label("\(count) ratings", systemImage: "person.3.fill")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.headline)

            let overview = vm.detail?.overview.isEmpty == false
                ? (vm.detail?.overview ?? "")
                : baseMovie.overview

            Text(overview)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("More like this")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.recommendations) { movie in
                        VStack(alignment: .leading, spacing: 6) {
                            if let url = movie.posterURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.secondarySystemBackground))
                                            .frame(width: 110, height: 165)
                                            .overlay { ProgressView() }
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 110, height: 165)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.secondarySystemBackground))
                                            .frame(width: 110, height: 165)
                                            .overlay {
                                                Image(systemName: "film")
                                                    .foregroundColor(.secondary)
                                            }
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                                    .frame(width: 110, height: 165)
                                    .overlay {
                                        Image(systemName: "film")
                                            .foregroundColor(.secondary)
                                    }
                            }

                            Text(movie.title)
                                .font(.caption)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .minimumScaleFactor(0.85)
                                .frame(width: 110, alignment: .leading)
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private var placeholder: some View {
        ZStack {
            Color(.secondarySystemBackground)
            Image(systemName: "film")
                .font(.largeTitle)
                .foregroundColor(.secondary)
        }
    }
}
