//
//  DiscoverView.swift
//  FilmFuel
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DiscoverView: View {
    @StateObject private var vm: DiscoverVM
    @State private var showingFilters = false
    @State private var showingPlusPaywall = false

    // For a little shuffle animation
    @State private var shuffleSpin = false

    @EnvironmentObject var store: FilmFuelStore
    @EnvironmentObject var entitlements: FilmFuelEntitlements

    /// Hook this up from the parent to show your Tip Jar / IAP
    var onTipTapped: (() -> Void)?

    init(
        client: TMDBClientProtocol = TMDBClient(),
        onTipTapped: (() -> Void)? = nil
    ) {
        _vm = StateObject(wrappedValue: DiscoverVM(client: client))
        self.onTipTapped = onTipTapped
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

                if vm.showTipNudge {
                    tipNudgeOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(), value: vm.showTipNudge)
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Global Filters button (all modes)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingFilters = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 17, weight: .semibold))

                            if vm.filters.isActive {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    .accessibilityLabel("Filters")
                }
            }
            .sheet(
                isPresented: $showingFilters,
                onDismiss: {
                    vm.loadInitial()
                }
            ) {
                DiscoverFiltersSheet(
                    filters: $vm.filters,
                    isPremiumUnlocked: entitlements.isPlus,
                    onUpgradeTapped: {
                        showingPlusPaywall = true
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingPlusPaywall) {
                FilmFuelPlusPaywallView()
                    .environmentObject(store)
                    .environmentObject(entitlements)
            }
            .onAppear {
                if vm.movies.isEmpty {
                    vm.loadInitial()
                }
            }
        }
    }

    // MARK: - Header (title + search + mode chips + moods + controls)

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title + Tip button
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Find your next watch")
                        .font(.title3.weight(.semibold))

                    Text(subtitleForMode(vm.mode))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let onTipTapped {
                    Button {
                        onTipTapped()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "popcorn")
                            Text("Tip")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            // Status row (Plus vs Free + Smart uses left)
            HStack(spacing: 8) {
                Circle()
                    .fill(entitlements.isPlus ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)

                Text(entitlements.isPlus ? "FilmFuel+ Active" : "Free tier")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Smart left: \(entitlements.freeSmartUsesRemainingToday)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()
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
                                scrollToTop()
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

            // Mood chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MovieMood.allCases) { mood in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vm.selectedMood = mood
                            }
                        } label: {
                            Text(mood.label)
                                .font(.caption)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(
                                    vm.selectedMood == mood
                                        ? Color.accentColor.opacity(0.18)
                                        : Color(.secondarySystemBackground)
                                )
                                .foregroundColor(
                                    vm.selectedMood == mood ? .accentColor : .primary
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            // Random flavor row (only in Random/For You mode)
            if vm.mode == .random {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DiscoverVM.RandomFlavor.allCases) { flavor in
                            let isLocked = (flavor == .fromYourTaste && !entitlements.isPlus)
                            let isSelected = (vm.randomFlavor == flavor)

                            Button {
                                if isLocked {
                                    showingPlusPaywall = true
                                    #if canImport(UIKit)
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.warning)
                                    #endif
                                } else {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        vm.randomFlavor = flavor
                                        vm.loadInitial()
                                        scrollToTop()
                                    }
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(flavor.shortLabel)
                                            .font(.caption.weight(
                                                isSelected && !isLocked ? .semibold : .regular
                                            ))

                                        if isLocked {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 9, weight: .bold))
                                        }
                                    }

                                    Text(flavor.subtitle)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .frame(minWidth: 130, alignment: .leading)
                                .background(
                                    (isSelected && !isLocked)
                                        ? Color.accentColor.opacity(0.18)
                                        : Color(.secondarySystemBackground)
                                )
                                .foregroundColor(
                                    isLocked
                                        ? .secondary
                                        : (isSelected ? .accentColor : .primary)
                                )
                                .overlay(
                                    RoundedRectangle(
                                        cornerRadius: 14,
                                        style: .continuous
                                    )
                                    .stroke(
                                        isLocked
                                            ? Color.secondary.opacity(0.4)
                                            : (isSelected
                                                ? Color.accentColor
                                                : Color.clear),
                                        lineWidth: isSelected || isLocked ? 1 : 0
                                    )
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 14,
                                        style: .continuous
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Random-only controls row: Filters + Sort + Smart Mode + Shuffle
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

                            if vm.filters.isActive {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                    }

                    // Sort menu
                    Menu {
                        ForEach(DiscoverSort.allCases) { sort in
                            Button {
                                vm.filters.sort = sort
                                vm.loadInitial()
                                scrollToTop()
                            } label: {
                                if vm.filters.sort == sort {
                                    Label(sort.label, systemImage: "checkmark")
                                } else {
                                    Text(sort.label)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 13, weight: .semibold))
                            Text(vm.filters.sort.label)
                                .font(.footnote.weight(.semibold))
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                    }

                    // Smart Mode toggle (gated by FilmFuel+)
                    Toggle(isOn: Binding(
                        get: { vm.useSmartMode },
                        set: { newValue in
                            if newValue {
                                if entitlements.isPlus {
                                    vm.useSmartMode = true
                                } else {
                                    if entitlements.consumeFreeSmartModeUseIfNeeded() {
                                        vm.useSmartMode = true
                                    } else {
                                        vm.useSmartMode = false
                                        showingPlusPaywall = true
                                    }
                                }
                            } else {
                                vm.useSmartMode = false
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Smart Mode")
                                .font(.footnote)
                            Text(entitlements.isPlus ? "Always on" : "2 free picks/day")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                    Spacer()

                    // Shuffle pill
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        shuffleSpin.toggle()
                        vm.shuffleRandomFeed()
                        scrollToTop()
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
                        .rotationEffect(.degrees(shuffleSpin ? 360 : 0))
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.7),
                            value: shuffleSpin
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 2)
            }

            // Taste profile summary
            if !vm.topGenreNames.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("FilmFuel Taste Profile:")
                        .font(.caption.weight(.semibold))
                    Text(vm.topGenreNames.joined(separator: " • "))
                        .font(.caption)
                    Spacer()
                }
                .foregroundColor(.secondary)
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
                if vm.displayedMovies.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film.slash")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)

                        Text(
                            vm.searchQuery.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty
                            ? "No movies to show"
                            : "No matches for “\(vm.searchQuery)”"
                        )
                        .font(.headline)

                        Text("Try adjusting your filters, mood, or random flavor to see more options.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if vm.filters.isActive || vm.selectedMood != .any ||
                            !vm.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                vm.searchQuery = ""
                                vm.filters = .default
                                vm.selectedMood = .any
                                vm.loadInitial()
                            } label: {
                                Text("Clear filters & reset")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 24) {
                            ForEach(vm.displayedMovies) { movie in
                                NavigationLink {
                                    MovieDetailView(movie: movie)
                                        .environmentObject(vm)
                                        .onAppear {
                                            vm.recordDetailOpen(movie)
                                        }
                                } label: {
                                    movieFeedCard(movie)
                                }
                                .buttonStyle(.plain)
                            }

                            // End-of-feed footer for Random
                            if vm.mode == .random && !vm.displayedMovies.isEmpty {
                                VStack(spacing: 8) {
                                    Text("End of this shuffle")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Hit Shuffle for a fresh batch of picks.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Button {
                                        #if canImport(UIKit)
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        #endif
                                        shuffleSpin.toggle()
                                        vm.shuffleRandomFeed()
                                        scrollToTop()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "shuffle")
                                            Text("Shuffle again")
                                                .font(.subheadline.weight(.semibold))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.accentColor.opacity(0.18))
                                        .clipShape(Capsule())
                                    }
                                }
                                .padding(.top, 4)
                                .padding(.bottom, 32)
                            } else {
                                Spacer(minLength: 24)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: vm.displayedMovies.map(\.id)
                    )
                }
            }
        }
    }

    // MARK: - Movie card

    private func movieFeedCard(_ movie: TMDBMovie) -> some View {
        let isInWatchlist = vm.isInWatchlist(movie)
        let isSeen = vm.isSeen(movie)
        let isDisliked = vm.isDisliked(movie)

        return VStack(alignment: .leading, spacing: 10) {
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
                        .minimumScaleFactor(0.8)
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

            // Actions row: Watchlist / Seen / Not for me
            HStack(spacing: 10) {
                Button {
                    vm.toggleWatchlist(movie)
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

                Button {
                    vm.toggleSeen(movie)
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

                Button {
                    vm.toggleDisliked(movie)
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

    // MARK: - Tip nudge overlay

    private var tipNudgeOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Boost FilmFuel?")
                        .font(.headline)
                    if let message = vm.tipNudgeMessage {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button {
                    vm.dismissTipNudge()
                } label: {
                    Text("Not now")
                        .font(.subheadline)
                }
                if let onTipTapped {
                    Button {
                        onTipTapped()
                        vm.recordTipSuccess()
                    } label: {
                        Text("Tip")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Helpers

    private func subtitleForMode(_ mode: DiscoverVM.Mode) -> String {
        switch mode {
        case .random:
            return "For you, based on mood & taste."
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

    /// Super lightweight way to snap user back to the top visually:
    /// you can expand this later using ScrollViewReader if you want pixel-perfect.
    private func scrollToTop() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIScrollView.scrollRectToVisible(_:animated:)),
            to: nil,
            from: nil,
            for: nil
        )
        #endif
    }
}
