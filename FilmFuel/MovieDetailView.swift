//
//  MovieDetailView.swift
//  FilmFuel
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct MovieDetailView: View {
    // Shared app state
    @EnvironmentObject var discoverVM: DiscoverVM
    @EnvironmentObject var entitlements: FilmFuelEntitlements
    @EnvironmentObject var store: FilmFuelStore

    // Local view model just for this screen
    @StateObject private var vm: MovieDetailVM

    // Paywall
    @State private var showingPlusPaywall = false

    // Taste training toast
    @State private var showTasteToast = false
    @State private var tasteToastText = ""

    // Convenience
    private var movie: TMDBMovie { vm.movie }

    init(
        movie: TMDBMovie,
        client: TMDBClientProtocol = TMDBClient()
    ) {
        _vm = StateObject(wrappedValue: MovieDetailVM(movie: movie, client: client))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerImageSection

                VStack(alignment: .leading, spacing: 16) {
                    infoCardSection          // title + meta + actions + taste training
                    smartMatchSection        // Smart Match score + reasons
                    smartInsightsSection     // Insight chips (Plus unlocks all)
                    overviewSection
                    genresSection
                    whereToWatchSection      // ⇐ back
                    ratingsSection
                    plusUpsellSection        // FilmFuel+ CTA
                    moreLikeThisSection      // ⇐ back

                    // Taste training confirmation toast
                    if showTasteToast {
                        tasteTrainingToast
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(vm.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.loadIfNeeded()
            // Let Discover know user opened this detail (for taste profile)
            discoverVM.recordDetailOpen(movie)
        }
        .overlay(alignment: .center) {
            if vm.isLoading && vm.detail == nil && vm.errorMessage == nil {
                ProgressView()
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .alert("Couldn’t load movie details", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { _ in vm.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let message = vm.errorMessage {
                Text(message)
            }
        }
        .sheet(isPresented: $showingPlusPaywall) {
            FilmFuelPlusPaywallView()
                .environmentObject(store)
                .environmentObject(entitlements)
        }
    }

    // MARK: - Header hero image

    private var headerImageSection: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let url = vm.headerImageURL {
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
                                .overlay { ProgressView() }

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
                        Color.black.opacity(0.15),
                        Color.black.opacity(0.80)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Glass card for title + year + rating
            VStack(alignment: .leading, spacing: 6) {
                Text(vm.displayTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 8) {
                    if vm.displayYearText != "—" {
                        Text(vm.displayYearText)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.18))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }

                    if let cert = vm.certification, !cert.isEmpty {
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
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Info card (title + meta + actions + taste training)

    private var infoCardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleSection
            metaChipsSection
            userActionsSection

            // Taste training (only if we have any genres info)
            let hasDetailGenres = (vm.detail?.genres.isEmpty == false)
            let hasBaseGenres = (movie.genreIDs?.isEmpty == false)

            if hasDetailGenres || hasBaseGenres {
                trainTasteButton
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(vm.displayTitle)
                .font(.title3.weight(.semibold))

            if let d = vm.detail,
               let taglineRaw = d.tagline,
               !taglineRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(taglineRaw)
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
                Text(String(format: "%.1f", vm.displayVoteAverage))
            }
            .font(.caption.weight(.medium))
            .foregroundColor(.yellow)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemYellow).opacity(0.15))
            .clipShape(Capsule())

            // Runtime chip
            if let runtimeText = vm.runtimeText {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(runtimeText)
                }
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Capsule())
            }

            // Vote count
            if vm.displayVoteCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill")
                    Text("\(vm.displayVoteCount) ratings")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Capsule())
            }

            Spacer()
        }
    }

    // MARK: - User actions row (watchlist / seen / not for me)

    private var userActionsSection: some View {
        let isInWatchlist = discoverVM.isInWatchlist(movie)
        let isSeen = discoverVM.isSeen(movie)
        let isDisliked = discoverVM.isDisliked(movie)

        return HStack(spacing: 10) {
            // Watchlist
            Button {
                discoverVM.toggleWatchlist(movie)
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isInWatchlist ? "bookmark.fill" : "bookmark")
                    Text("Watchlist")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isInWatchlist
                    ? Color.accentColor.opacity(0.18)
                    : Color(.secondarySystemBackground)
                )
                .foregroundColor(isInWatchlist ? .accentColor : .primary)
                .clipShape(Capsule())
            }

            // Seen it
            Button {
                discoverVM.toggleSeen(movie)
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                #endif
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isSeen ? "eye.fill" : "eye")
                    Text("Seen it")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isSeen
                    ? Color.green.opacity(0.18)
                    : Color(.secondarySystemBackground)
                )
                .foregroundColor(isSeen ? .green : .primary)
                .clipShape(Capsule())
            }

            // Not for me
            Button {
                discoverVM.toggleDisliked(movie)
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    Text("Not for me")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isDisliked
                    ? Color.red.opacity(0.16)
                    : Color(.secondarySystemBackground)
                )
                .foregroundColor(isDisliked ? .red : .primary)
                .clipShape(Capsule())
            }

            Spacer()
        }
    }

    // MARK: - Taste training button

    private var trainTasteButton: some View {
        let isPlus = entitlements.isPlus

        return Button {
            // Train taste via DiscoverVM
            discoverVM.trainTaste(on: movie, isStrong: isPlus)

            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            #endif

            if isPlus {
                tasteToastText = "Boosted: FilmFuel+ will lean harder into picks like this."
            } else {
                tasteToastText = "Got it — we’ll lean a bit more into movies like this."
            }

            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showTasteToast = true
            }

            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showTasteToast = false
                    }
                }
            }

        } label: {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                Text(isPlus ? "Boost my taste on this" : "Train my taste on this")
                    .font(.footnote.weight(.semibold))

                if isPlus {
                    Image(systemName: "sparkles")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isPlus
                ? Color.accentColor.opacity(0.18)
                : Color(.tertiarySystemBackground)
            )
            .foregroundColor(isPlus ? .accentColor : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var tasteTrainingToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.subheadline)
                .foregroundColor(.accentColor)
            Text(tasteToastText)
                .font(.footnote)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Smart Match section

    private var smartMatchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.subheadline)
                Text("Smart match for you")
                    .font(.headline)
                Spacer()

                Text("\(vm.smartMatchScore)%")
                    .font(.title3.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.18))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 4) {
                let reasons = vm.smartReasonLines
                if entitlements.isPlus {
                    ForEach(reasons, id: \.self) { line in
                        Text("• \(line)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    if let first = reasons.first {
                        Text("• \(first)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if reasons.count > 1 {
                        Text("Unlock FilmFuel+ to see the full breakdown of why this matches your taste.")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.9))
                            .padding(.top, 2)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Smart Insights section

    private var smartInsightsSection: some View {
        let chips = vm.quickInsights
        guard !chips.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb")
                    Text("Smart insights")
                        .font(.headline)
                    Spacer()
                    if !entitlements.isPlus {
                        Text("FilmFuel+")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.18))
                            .clipShape(Capsule())
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if entitlements.isPlus {
                            ForEach(chips, id: \.self) { chip in
                                insightChip(text: chip, highlighted: true)
                            }
                        } else {
                            // Show first chip for free, hint there is more with Plus
                            if let first = chips.first {
                                insightChip(text: first, highlighted: false)
                            }
                            if chips.count > 1 {
                                insightChip(
                                    text: "+\(chips.count - 1) more insights with FilmFuel+",
                                    highlighted: true
                                )
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        )
    }

    private func insightChip(text: String, highlighted: Bool) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                highlighted
                ? Color.accentColor.opacity(0.18)
                : Color(.tertiarySystemBackground)
            )
            .foregroundColor(highlighted ? .accentColor : .primary)
            .clipShape(Capsule())
    }

    // MARK: - Overview

    private var overviewSection: some View {
        Group {
            if let overview = vm.overviewText {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overview")
                        .font(.headline)
                    Text(overview)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var genresSection: some View {
        Group {
            if let d = vm.detail {
                let genres = d.genres
                if !genres.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Genres")
                            .font(.headline)

                        FlexibleGenreChips(genres: genres)
                    }
                }
            }
        }
    }

    // MARK: - Where to watch (via TMDB link)

    private var whereToWatchSection: some View {
        Group {
            if let url = vm.whereToWatchURL {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Where to watch")
                        .font(.headline)

                    Text("Streaming availability can change. Check the latest providers on TMDB:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "tv")
                            Text("View watch options on TMDB")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.18))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var ratingsSection: some View {
        Group {
            if let cert = vm.certification, !cert.isEmpty {
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

    // MARK: - FilmFuel+ upsell (detail screen monetization)

    private var plusUpsellSection: some View {
        Group {
            if !entitlements.isPlus {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Supercharge your picks")
                            .font(.headline)
                    }

                    Text("Unlock FilmFuel+ for full Smart Match breakdowns, all Smart Insights, deeper recommendations, and boosted Smart Mode in Discover.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button {
                        showingPlusPaywall = true
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                    } label: {
                        HStack(spacing: 6) {
                            Text("Unlock FilmFuel+")
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    // MARK: - More like this (from Discover feed)

    /// Simple recommendations using current Discover feed:
    /// - Same / overlapping genres
    /// - Excludes current movie
    /// - Sorted by genre overlap, then rating
    private var moreLikeThisMovies: [TMDBMovie] {
        let baseGenres = Set(movie.genreIDs ?? [])
        guard !baseGenres.isEmpty else { return [] }

        let candidates = discoverVM.displayedMovies.filter { $0.id != movie.id }

        let scored: [(TMDBMovie, Int)] = candidates.compactMap { candidate in
            let overlap = baseGenres.intersection(Set(candidate.genreIDs ?? [])).count
            return overlap > 0 ? (candidate, overlap) : nil
        }

        let sorted = scored.sorted { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.0.voteAverage > rhs.0.voteAverage
            }
            return lhs.1 > rhs.1
        }

        return Array(sorted.prefix(12).map { $0.0 })
    }

    private var moreLikeThisSection: some View {
        Group {
            let recs = moreLikeThisMovies
            if !recs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("More like this")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(recs) { rec in
                                NavigationLink {
                                    MovieDetailView(movie: rec)
                                        .environmentObject(discoverVM)
                                        .environmentObject(entitlements)
                                        .environmentObject(store)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        AsyncImage(url: rec.posterURL) { phase in
                                            switch phase {
                                            case .empty:
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(Color(.secondarySystemBackground))
                                                    .frame(width: 110, height: 165)
                                                    .overlay { ProgressView() }

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
        #if canImport(UIKit)
        let controller = UIHostingController(rootView: self)
        return controller.view.intrinsicContentSize.width
        #else
        return 0
        #endif
    }

    func asArray() -> [AnyView] {
        [self.eraseToAnyView()]
    }
}
