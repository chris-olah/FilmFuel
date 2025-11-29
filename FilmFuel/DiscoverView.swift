//
//  DiscoverView.swift
//  FilmFuel
//
//  Redesigned for maximum retention & monetization
//  Key patterns: Visual progress, social proof, streak anxiety, variable rewards,
//  strategic friction, FOMO triggers, gamification
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DiscoverView: View {
    @StateObject private var vm: DiscoverVM
    @State private var showingFilters = false
    @State private var showingPlusPaywall = false
    @State private var showingProfile = false
    @State private var showingAchievements = false
    @State private var shuffleSpin = false
    @State private var pulseStreak = false
    @State private var showMatchAnimation = false
    @State private var celebratedMovieID: Int?
    
    @EnvironmentObject var store: FilmFuelStore
    @EnvironmentObject var entitlements: FilmFuelEntitlements
    
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
                Color(.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerSection
                    content
                }
                
                // Floating overlays
                if vm.showTipNudge {
                    tipNudgeOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                if vm.showStreakAtRisk {
                    streakAtRiskOverlay
                        .transition(.scale.combined(with: .opacity))
                }
                
                if vm.showRewardAnimation, let reward = vm.pendingReward {
                    rewardCelebration(reward)
                        .transition(.scale.combined(with: .opacity))
                }
                
                if vm.showLevelUp, let level = vm.newLevelReached {
                    levelUpCelebration(level)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    filterButton
                }
                ToolbarItem(placement: .principal) {
                    streakBadge
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    profileButton
                }
            }
            .sheet(isPresented: $showingFilters, onDismiss: { vm.loadInitial() }) {
                DiscoverFiltersSheet(
                    filters: $vm.filters,
                    isPremiumUnlocked: entitlements.isPlus,
                    onUpgradeTapped: { showingPlusPaywall = true }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingPlusPaywall) {
                FilmFuelPlusPaywallView()
                    .environmentObject(store)
                    .environmentObject(entitlements)
            }
            .sheet(isPresented: $showingProfile) {
                ProfileSheet(vm: vm, entitlements: entitlements)
            }
            .sheet(isPresented: $showingAchievements) {
                AchievementsSheet(achievements: vm.achievements, userXP: vm.userXP, userLevel: vm.userLevel)
            }
            .onAppear {
                if vm.movies.isEmpty {
                    vm.loadInitial()
                }
            }
            .animation(.spring(), value: vm.showTipNudge)
            .animation(.spring(), value: vm.showStreakAtRisk)
            .animation(.spring(), value: vm.showRewardAnimation)
            .animation(.spring(), value: vm.showLevelUp)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // More compact hero card
            heroCard
            
            // Mode selector
            modeSegmentedControl
            
            // Mood + flavor rail
            moodAndFlavorSection
            
            // Taste summary with progress
            if !vm.topGenreNames.isEmpty || vm.favoriteDecadeLabel != nil {
                tasteSummary
            }
            
            // Social proof bar
            socialProofBar
        }
        .padding(.top, 8)
    }
    
    private var heroCard: some View {
        VStack(spacing: 10) {
            // Top row: Title + Smart picks remaining
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Find your next watch")
                        .font(.title2.weight(.bold))
                    
                    Text(subtitleForMode(vm.mode))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Smart picks indicator (creates urgency)
                smartPicksIndicator
            }
            
            // Level + XP progress + weekly goal summary in one tight row
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: vm.userLevel.icon)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.accentColor)
                        
                        Text(vm.userLevel.title)
                            .font(.caption.weight(.semibold))
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.tertiarySystemFill))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.accentColor, .accentColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * vm.levelProgress)
                        }
                    }
                    .frame(height: 6)
                    
                    if let next = vm.userLevel.next {
                        Text("\(vm.xpToNextLevel) XP to \(next.title)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("\(vm.weeklyProgress)/\(vm.weeklyGoal)")
                            .font(.caption.weight(.semibold))
                    }
                    Text("this week")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Search + Plus chip in one row
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search movies…", text: $vm.searchQuery)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                Button {
                    if entitlements.isPlus {
                        // Maybe later: open Plus perks screen
                    } else {
                        showingPlusPaywall = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("FilmFuel+")
                        Image(systemName: entitlements.isPlus ? "checkmark.seal.fill" : "sparkles")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        entitlements.isPlus
                            ? Color.accentColor.opacity(0.18)
                            : Color.accentColor.opacity(0.12)
                    )
                    .foregroundColor(entitlements.isPlus ? .accentColor : .accentColor)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
    }
    
    private var smartPicksIndicator: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.semibold))
                Text("\(vm.smartPicksRemaining)")
                    .font(.title3.weight(.bold))
            }
            .foregroundColor(vm.smartPicksRemaining <= 1 ? .orange : .accentColor)
            
            Text("smart picks left")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if vm.smartPicksRemaining <= 1 && !entitlements.isPlus {
                Button {
                    showingPlusPaywall = true
                } label: {
                    Text("Get more")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    private var modeSegmentedControl: some View {
        HStack(spacing: 6) {
            ForEach(DiscoverVM.Mode.allCases) { mode in
                modeButton(mode)
            }
        }
        .padding(.horizontal)
    }
    
    private func modeButton(_ mode: DiscoverVM.Mode) -> some View {
        let isSelected = vm.mode == mode
        let isLocked = mode.isPremium && !entitlements.isPlus
        
        return Button {
            if isLocked {
                vm.paywallTrigger = .hardPaywall(feature: mode.label)
                showingPlusPaywall = true
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                #endif
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    vm.userSelectedMode(mode)
                    scrollToTop()
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: mode.icon)
                Text(mode.label)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                }
            }
            .font(.footnote.weight(isSelected ? .semibold : .regular))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor :
                isLocked ? Color(.tertiarySystemBackground) :
                Color(.secondarySystemBackground)
            )
            .foregroundColor(
                isSelected ? .white :
                isLocked ? .secondary :
                .primary
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var moodAndFlavorSection: some View {
        VStack(spacing: 10) {
            // Mood rail
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MovieMood.allCases) { mood in
                        moodChip(mood)
                    }
                }
                .padding(.horizontal)
            }
            
            // Flavor chips (in For You mode)
            if vm.mode == .forYou {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DiscoverVM.RandomFlavor.allCases) { flavor in
                            flavorChip(flavor)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Controls row
            if vm.mode == .forYou {
                HStack(spacing: 10) {
                    smartModeToggle
                    
                    Spacer()
                    
                    shuffleButton
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func moodChip(_ mood: MovieMood) -> some View {
        let isSelected = vm.selectedMood == mood
        
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                vm.userSelectedMood(mood)
            }
        } label: {
            HStack(spacing: 4) {
                Text(mood.emoji)
                Text(mood.label)
            }
            .font(.caption.weight(isSelected ? .semibold : .regular))
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private func flavorChip(_ flavor: DiscoverVM.RandomFlavor) -> some View {
        let isLocked = flavor.isPremium && !entitlements.isPlus
        let isSelected = vm.randomFlavor == flavor
        
        return Button {
            if isLocked {
                showingPlusPaywall = true
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                #endif
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    vm.randomFlavor = flavor
                    vm.loadInitial()
                    scrollToTop()
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(flavor.shortLabel)
                    .font(.caption.weight(isSelected && !isLocked ? .semibold : .regular))
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                (isSelected && !isLocked)
                    ? Color.accentColor.opacity(0.18)
                    : Color(.secondarySystemBackground)
            )
            .foregroundColor(
                isLocked ? .secondary :
                isSelected ? .accentColor :
                .primary
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var smartModeToggle: some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { vm.useSmartMode },
                set: handleSmartToggle
            )) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text("Smart mode")
                }
                .font(.footnote.weight(.semibold))
            }
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        }
    }
    
    private var shuffleButton: some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            shuffleSpin.toggle()
            vm.shuffleRandomFeed()
            scrollToTop()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "shuffle")
                    .rotationEffect(.degrees(shuffleSpin ? 360 : 0))
                Text("Shuffle")
            }
            .font(.footnote.weight(.semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: shuffleSpin)
    }
    
    private var tasteSummary: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
            Text("Your taste:")
                .font(.caption.weight(.semibold))
            
            let pieces: [String] = {
                var parts: [String] = []
                if !vm.topGenreNames.isEmpty {
                    parts.append(vm.topGenreNames.joined(separator: " • "))
                }
                if let dec = vm.favoriteDecadeLabel {
                    parts.append("\(dec) era")
                }
                return parts
            }()
            
            Text(pieces.joined(separator: " • "))
                .font(.caption)
            
            Spacer()
            
            // Taste strength indicator
            tasteStrengthIndicator
        }
        .foregroundColor(.secondary)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
    
    private var tasteStrengthIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Double(i) / 5.0 < vm.tasteProfile.tasteStrength ? Color.accentColor : Color(.tertiarySystemFill))
                    .frame(width: 3, height: 8 + Double(i) * 2)
            }
        }
    }
    
    private var socialProofBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("\(vm.activeUsersNow.formatted()) discovering now")
                    .font(.caption2)
            }
            
            Text("•")
                .foregroundColor(.secondary)
            
            Text("\(vm.moviesDiscoveredToday.formatted()) movies found today")
                .font(.caption2)
            
            Spacer()
        }
        .foregroundColor(.secondary)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Toolbar Items
    
    private var filterButton: some View {
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
    
    private var streakBadge: some View {
        Button {
            pulseStreak.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundColor(vm.currentStreak >= 7 ? .orange : .secondary)
                Text("\(vm.currentStreak)")
                    .font(.headline.weight(.bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                vm.currentStreak >= 7
                    ? Color.orange.opacity(0.15)
                    : Color(.secondarySystemBackground)
            )
            .clipShape(Capsule())
            .scaleEffect(pulseStreak ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: pulseStreak)
    }
    
    private var profileButton: some View {
        Button {
            showingProfile = true
        } label: {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.accentColor)
        }
    }
    
    // MARK: - Content
    
    private var content: some View {
        Group {
            if vm.isLoading && vm.movies.isEmpty {
                loadingState
            } else if let error = vm.errorMessage, vm.movies.isEmpty {
                errorState(error)
            } else if vm.displayedMovies.isEmpty {
                emptyState
            } else {
                movieList
            }
        }
    }
    
    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(loadingMessageForMode(vm.mode))
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorState(_ error: String) -> some View {
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
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.slash")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text(
                vm.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "No movies to show"
                    : "No matches for \"\(vm.searchQuery)\""
            )
            .font(.headline)
            
            Text("Try adjusting your filters or mood")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if vm.filters.isActive || vm.selectedMood != .any {
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
    }
    
    private var movieList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 18) {
                ForEach(Array(vm.displayedMovies.enumerated()), id: \.element.id) { index, movie in
                    NavigationLink {
                        MovieDetailView(movie: movie)
                            .environmentObject(vm)
                            .onAppear { vm.recordDetailOpen(movie) }
                    } label: {
                        movieFeedCard(movie, index: index)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .buttonStyle(.plain)
                }
                
                endOfFeedFooter
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: vm.displayedMovies.map(\.id))
    }
    
    private func movieFeedCard(_ movie: TMDBMovie, index: Int) -> some View {
        let isInWatchlist = vm.isInWatchlist(movie)
        let isSeen = vm.isSeen(movie)
        let isDisliked = vm.isDisliked(movie)
        let isFavorite = vm.isFavorite(movie)
        let reason = vm.briefReasonFor(movie)
        let matchBadge = vm.matchBadgeText(for: movie)
        
        return VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                // Poster/backdrop
                posterImage(for: movie)
                
                // Top overlays
                VStack {
                    HStack {
                        // Match badge (creates excitement)
                        if let badge = matchBadge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    matchPercentageColor(badge)
                                )
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        } else if vm.useSmartMode && vm.mode == .forYou {
                            Text(vm.randomFlavor == .fromYourTaste ? "Your taste" : "Smart pick")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        // Favorite button
                        Button {
                            vm.toggleFavorite(movie)
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            #endif
                        } label: {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isFavorite ? .red : .white)
                                .padding(10)
                                .background(.thinMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                    }
                    Spacer()
                }
                .padding(10)
                
                // Bottom overlay
                VStack(alignment: .leading, spacing: 6) {
                    if let reason, vm.mode == .forYou {
                        Text(reason)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white.opacity(0.95))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Capsule())
                            .shadow(radius: 6)
                    }
                    
                    Text(movie.title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
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
                        
                        Label(String(format: "%.1f", movie.voteAverage), systemImage: "star.fill")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Capsule())
                    }
                }
                .padding(14)
            }
            
            // Overview
            if !movie.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(movie.overview)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            // Meta row
            HStack(spacing: 8) {
                if movie.voteCount > 0 {
                    Label("\(movie.voteCount.formatted()) ratings", systemImage: "person.3.fill")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.9))
                }
                Spacer()
            }
            
            // Action buttons
            actionButtons(movie: movie, isInWatchlist: isInWatchlist, isSeen: isSeen, isDisliked: isDisliked)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 4)
        .contentShape(Rectangle())
    }
    
    private func posterImage(for movie: TMDBMovie) -> some View {
        Group {
            if let url = movie.backdropURL ?? movie.posterURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle().overlay { ProgressView() }
                    case .success(let image):
                        image.resizable().scaledToFill()
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
                colors: [Color.black.opacity(0.15), Color.black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    private func matchPercentageColor(_ badge: String) -> Color {
        if badge.contains("9") {
            return .green
        } else if badge.contains("8") {
            return .accentColor
        } else {
            return .orange
        }
    }
    
    private func actionButtons(movie: TMDBMovie, isInWatchlist: Bool, isSeen: Bool, isDisliked: Bool) -> some View {
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
                .background(isInWatchlist ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
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
                .background(isSeen ? Color.green.opacity(0.18) : Color(.secondarySystemBackground))
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
                .background(isDisliked ? Color.red.opacity(0.16) : Color(.secondarySystemBackground))
                .foregroundColor(isDisliked ? .red : .primary)
                .clipShape(Capsule())
            }
            
            Spacer()
        }
    }
    
    private var posterPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.secondarySystemBackground), Color(.tertiarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "film")
                .font(.largeTitle)
                .foregroundColor(.secondary)
        }
    }
    
    private var endOfFeedFooter: some View {
        Group {
            if vm.mode == .forYou && !vm.displayedMovies.isEmpty {
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
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                    
                    // Upsell at end of feed
                    if !entitlements.isPlus {
                        VStack(spacing: 6) {
                            Text("Want unlimited smart shuffles?")
                                .font(.caption.weight(.semibold))
                            Button {
                                showingPlusPaywall = true
                            } label: {
                                Text("Try FilmFuel+")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 32)
            } else {
                Spacer(minLength: 24)
            }
        }
    }
    
    // MARK: - Overlays
    
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
                Button { vm.dismissTipNudge() } label: {
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
    
    private var streakAtRiskOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keep your \(vm.currentStreak)-day streak!")
                            .font(.headline)
                        Text("Discover a movie before midnight")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Button {
                        vm.showStreakAtRisk = false
                    } label: {
                        Text("Got it")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal)
            .padding(.bottom, 50)
        }
    }
    
    private func rewardCelebration(_ reward: RewardType) -> some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: reward.icon)
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                Text(reward.title)
                    .font(.title2.weight(.bold))
                
                Text("Keep discovering to earn more rewards!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    vm.showRewardAnimation = false
                    vm.pendingReward = nil
                } label: {
                    Text("Awesome!")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(24)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .background(Color.black.opacity(0.4).ignoresSafeArea())
    }
    
    private func levelUpCelebration(_ level: UserLevel) -> some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: level.icon)
                    .font(.system(size: 56))
                    .foregroundColor(.accentColor)
                
                Text("Level Up!")
                    .font(.largeTitle.weight(.bold))
                
                Text("You're now a \(level.title)")
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("New perks unlocked:")
                        .font(.subheadline.weight(.semibold))
                    
                    ForEach(level.perks, id: \.self) { perk in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(perk)
                                .font(.subheadline)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Button {
                    vm.showLevelUp = false
                    vm.newLevelReached = nil
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(24)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .background(Color.black.opacity(0.5).ignoresSafeArea())
    }
    
    // MARK: - Helpers
    
    private func handleSmartToggle(_ newValue: Bool) {
        if newValue {
            if entitlements.isPlus {
                vm.useSmartMode = true
            } else if vm.consumeSmartPick() {
                vm.useSmartMode = true
            } else {
                vm.useSmartMode = false
                vm.paywallTrigger = .limitReached(type: "Smart picks", remaining: 0)
                showingPlusPaywall = true
            }
        } else {
            vm.useSmartMode = false
        }
    }
    
    private func subtitleForMode(_ mode: DiscoverVM.Mode) -> String {
        switch mode {
        case .forYou:     return "Personalized picks based on your taste"
        case .trending:   return "What everyone's watching right now"
        case .popular:    return "All-time crowd favorites"
        case .hiddenGems: return "Underrated films you'll love"
        }
    }
    
    private func loadingMessageForMode(_ mode: DiscoverVM.Mode) -> String {
        switch mode {
        case .forYou:     return "Finding your perfect matches…"
        case .trending:   return "Fetching what's hot right now…"
        case .popular:    return "Loading all-time favorites…"
        case .hiddenGems: return "Uncovering hidden treasures…"
        }
    }
    
    private func scrollToTop() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIScrollView.scrollRectToVisible(_:animated:)),
            to: nil, from: nil, for: nil
        )
        #endif
    }
}

// MARK: - Profile Sheet

struct ProfileSheet: View {
    @ObservedObject var vm: DiscoverVM
    @ObservedObject var entitlements: FilmFuelEntitlements
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: vm.userLevel.icon)
                            .font(.title)
                            .foregroundColor(.accentColor)
                            .frame(width: 50, height: 50)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vm.userLevel.title)
                                .font(.headline)
                            Text("\(vm.userXP) XP")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                Text("\(vm.currentStreak)")
                                    .font(.headline)
                            }
                            Text("day streak")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Stats") {
                    ProfileStatRow(icon: "heart.fill", color: .red, label: "Favorites", value: "\(vm.favorites.count)")
                    ProfileStatRow(icon: "bookmark.fill", color: .accentColor, label: "Watchlist", value: "\(vm.watchlistMovieIDs.count)")
                    ProfileStatRow(icon: "eye.fill", color: .green, label: "Seen", value: "\(vm.seenMovieIDs.count)")
                }
                
                Section("Your Taste") {
                    if !vm.topGenreNames.isEmpty {
                        HStack {
                            Text("Top genres")
                            Spacer()
                            Text(vm.topGenreNames.joined(separator: ", "))
                                .foregroundColor(.secondary)
                        }
                    }
                    if let decade = vm.favoriteDecadeLabel {
                        HStack {
                            Text("Favorite era")
                            Spacer()
                            Text("\(decade)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ProfileStatRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Achievements Sheet

struct AchievementsSheet: View {
    let achievements: [Achievement]
    let userXP: Int
    let userLevel: UserLevel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Text("\(userXP) XP")
                            .font(.largeTitle.weight(.bold))
                        Text(userLevel.title)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                Section("Achievements") {
                    ForEach(achievements) { achievement in
                        HStack(spacing: 12) {
                            Image(systemName: achievement.icon)
                                .font(.title2)
                                .foregroundColor(achievement.isUnlocked ? .accentColor : .secondary)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                                Text(achievement.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if achievement.isUnlocked {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Text("+\(achievement.xpReward) XP")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .opacity(achievement.isUnlocked ? 1.0 : 0.6)
                    }
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
