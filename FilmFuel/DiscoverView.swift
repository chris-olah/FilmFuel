import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DiscoverView: View {
    @StateObject private var vm: DiscoverVM
    @State private var showingFilters = false

    init(client: TMDBClientProtocol = TMDBClient()) {
        _vm = StateObject(wrappedValue: DiscoverVM(client: client))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    content
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // You can keep or remove this global Filters button.
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingFilters = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .accessibilityLabel("Filters")
                }
            }
            .sheet(isPresented: $showingFilters) {
                FiltersComingSoonSheet(currentMode: vm.mode)
            }
            .onAppear {
                if vm.movies.isEmpty {
                    vm.loadInitial()
                }
            }
        }
    }

    // MARK: - Header (title + search + mode chips + random controls)

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title + subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text("Find your next watch")
                    .font(.title3.weight(.semibold))

                Text(subtitleForMode(vm.mode))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search movies…", text: $vm.searchQuery)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal)

            // Mode chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DiscoverVM.Mode.allCases) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vm.userSelectedMode(mode)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: iconForMode(mode))
                                    .font(.caption2)

                                Text(mode.label)
                                    .font(.caption)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(
                                vm.mode == mode
                                    ? Color.accentColor.opacity(0.18)
                                    : Color(.systemBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 999)
                                    .stroke(
                                        vm.mode == mode
                                            ? Color.accentColor
                                            : Color(.separator),
                                        lineWidth: 1
                                    )
                            )
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Random-only controls row: Filters + Shuffle
            if vm.mode == .random {
                HStack(spacing: 10) {
                    // Filters pill
                    Button {
                        showingFilters = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Filters")
                                .font(.footnote.weight(.semibold))
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                    }

                    // Shuffle pill
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        vm.loadInitial()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Shuffle")
                                .font(.footnote.weight(.semibold))
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 12)
                        .background(Color.accentColor.opacity(0.18))
                        .overlay(
                            Capsule()
                                .stroke(Color.accentColor, lineWidth: 1)
                        )
                        .clipShape(Capsule())
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Main content

    private var content: some View {
        Group {
            if vm.isLoading && vm.movies.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(loadingMessageForMode(vm.mode))
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.errorMessage, vm.movies.isEmpty {
                VStack(spacing: 12) {
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button {
                        vm.loadInitial()
                    } label: {
                        Text("Try again")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 24) {
                        ForEach(vm.movies) { movie in
                            NavigationLink {
                                MovieDetailView(movie: movie)
                            } label: {
                                movieFeedCard(movie)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    // Single place we add horizontal padding so everything lines up
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .animation(.easeInOut(duration: 0.25), value: vm.movies.map(\.id))
            }
        }
    }

    // MARK: - Movie card

    private func movieFeedCard(_ movie: TMDBMovie) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let url = movie.backdropURL ?? movie.posterURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .overlay {
                                        ProgressView()
                                    }

                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()

                            case .failure:
                                posterPlaceholder

                            @unknown default:
                                posterPlaceholder
                            }
                        }
                    } else {
                        posterPlaceholder
                    }
                }
                // Constrain to a 16:9 box
                .aspectRatio(16/9, contentMode: .fit)
                .frame(maxWidth: .infinity, alignment: .center)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.65)
                        ],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // Bottom-left overlay: title + meta
                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(radius: 10)

                    HStack(spacing: 8) {
                        if movie.yearText != "—" {
                            Text(movie.yearText)
                                .font(.caption.weight(.medium))
                                .foregroundColor(.white.opacity(0.9))
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
                }
                .padding(14)

                // Top-right: favorite button
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            vm.toggleFavorite(movie)
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            #endif
                        } label: {
                            Image(systemName: vm.isFavorite(movie) ? "heart.fill" : "heart")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(vm.isFavorite(movie) ? .red : .white)
                                .padding(10)
                                .background(.thinMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                    }
                    Spacer()
                }
                .padding(10)
            }

            // Below-image text
            if !movie.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(movie.overview)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
            }

            // Tiny meta row underneath
            HStack(spacing: 8) {
                if movie.voteCount > 0 {
                    Label("\(movie.voteCount) ratings", systemImage: "person.3.fill")
                }
                Spacer()
            }
            .font(.caption)
            .foregroundColor(.secondary.opacity(0.9))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
        .contentShape(Rectangle())
    }

    private var posterPlaceholder: some View {
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

    // MARK: - Helpers

    private func subtitleForMode(_ mode: DiscoverVM.Mode) -> String {
        switch mode {
        case .random:
            return "A fresh mix of movies from all over TMDB."
        case .trending:
            return "What movie fans are talking about today."
        case .popular:
            return "All-time crowd favorites and hits."
        }
    }

    private func iconForMode(_ mode: DiscoverVM.Mode) -> String {
        switch mode {
        case .random:   return "sparkles"
        case .trending: return "flame.fill"
        case .popular:  return "star.circle.fill"
        }
    }

    private func loadingMessageForMode(_ mode: DiscoverVM.Mode) -> String {
        switch mode {
            case .random:
                return "Digging up fresh picks…"
            case .trending:
                return "Fetching what’s hot right now…"
            case .popular:
                return "Loading all-time favorites…"
        }
    }
}

// MARK: - Filters stub (future monetization hook)

private struct FiltersComingSoonSheet: View {
    let currentMode: DiscoverVM.Mode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Filters coming soon")
                    .font(.title2.weight(.semibold))

                Text("You’ll be able to refine \(modeName) results by year, rating, and genre. Perfect for movie nights when you know the vibe but not the title.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Filter by decade", systemImage: "timeline.selection")
                    Label("Minimum rating", systemImage: "star.leadinghalf.filled")
                    Label("Genres & moods", systemImage: "theatermasks")
                }
                .font(.subheadline)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Got it")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding()
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var modeName: String {
        switch currentMode {
        case .random:   return "Random"
        case .trending: return "Trending"
        case .popular:  return "Popular"
        }
    }
}
