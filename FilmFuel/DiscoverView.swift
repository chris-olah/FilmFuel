//
//  DiscoverView.swift
//  FilmFuel
//
//  REDESIGNED: Modern, clean interface with natural premium value moments
//  Philosophy: Show users the VALUE of premium, don't manipulate with urgency
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DiscoverView: View {
    @EnvironmentObject private var vm: DiscoverVM
    @State private var showingFilters = false
    @State private var showingPlusPaywall = false
    @State private var selectedMovie: TMDBMovie? = nil
    
    @EnvironmentObject var store: FilmFuelStore
    @EnvironmentObject var entitlements: FilmFuelEntitlements
    
    var onTipTapped: (() -> Void)?
    
    init(
        onTipTapped: (() -> Void)? = nil
    ) {
        self.onTipTapped = onTipTapped
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Inline search bar
                    inlineSearchBar
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    // Mode/mood selectors — hidden while searching
                    if !vm.isSearching {
                        headerSection
                        moodFilterSection

                        if !entitlements.isPlus {
                            premiumFeaturesTeaser
                        }

                        if entitlements.isPlus {
                            smartMatchBanner
                        }
                    }

                    // Movie content (grid or search results)
                    movieContent
                }
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    logoTitle
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingButtons
                }
            }
            .sheet(isPresented: $showingFilters) {
                DiscoverFiltersSheet(
                    filters: $vm.filters,
                    isPremiumUnlocked: entitlements.isPlus,
                    onUpgradeTapped: {
                        showingFilters = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showingPlusPaywall = true
                        }
                    },
                    onApply: {
                        vm.loadInitial()
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingPlusPaywall) {
                FilmFuelPlusPaywallView()
                    .environmentObject(store)
                    .environmentObject(entitlements)
            }
            // Single movie detail sheet — discoverVM (vm) is always in scope here
            .sheet(item: $selectedMovie) { movie in
                NavigationStack {
                    MovieDetailView(movie: movie)
                        .environmentObject(vm)
                        .environmentObject(entitlements)
                        .environmentObject(store)
                }
            }
            .onAppear {
                if vm.movies.isEmpty {
                    vm.loadInitial()
                }
            }
        }
    }

    // MARK: - Inline Search Bar

    private var inlineSearchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search movies…", text: $vm.searchQuery)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)

                if !vm.searchQuery.isEmpty {
                    Button {
                        vm.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Filter button inline with search bar
            Button {
                showingFilters = true
                haptic(.light)
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body.weight(.medium))
                        .foregroundColor(vm.filters.isActive ? .accentColor : .primary)
                        .frame(width: 36, height: 36)
                        .background(
                            vm.filters.isActive
                                ? Color.accentColor.opacity(0.12)
                                : Color(.secondarySystemBackground)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    if vm.filters.isActive {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var logoTitle: some View {
        HStack(spacing: 6) {
            Text("Discover")
                .font(.headline)
            
            if entitlements.isPlus {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Mode selector
            HStack(spacing: 8) {
                modePill("For You", icon: "sparkles", mode: .forYou)
                modePill("Trending", icon: "flame", mode: .trending)
                modePill("Popular", icon: "star", mode: .popular)
                
                // Hidden Gems - Premium feature
                modePill("Gems", icon: "diamond", mode: .hiddenGems, isPremium: true)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    private func modePill(_ label: String, icon: String, mode: DiscoverVM.Mode, isPremium: Bool = false) -> some View {
        let isSelected = vm.mode == mode
        let isLocked = isPremium && !entitlements.isPlus
        
        return Button {
            if isLocked {
                showingPlusPaywall = true
                haptic(.warning)
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    vm.userSelectedMode(mode)
                }
                haptic(.light)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(label)
                    .font(.caption.weight(isSelected ? .semibold : .medium))
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                }
            }
            .padding(.horizontal, 12)
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
    
    // MARK: - Mood Filters
    
    private var moodFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All chip (uses .any)
                moodChip(.any)
                
                // Other mood chips (skip .any in the loop)
                ForEach(MovieMood.allCases.filter { $0 != .any }) { mood in
                    moodChip(mood)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }
    
    private func moodChip(_ mood: MovieMood) -> some View {
        let isSelected = vm.selectedMood == mood
        
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                vm.userSelectedMood(mood)
            }
            haptic(.light)
        } label: {
            HStack(spacing: 4) {
                Text(mood.emoji)
                Text(mood.label)
            }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Premium Features Teaser (Key Monetization)
    
    private var premiumFeaturesTeaser: some View {
        Button {
            showingPlusPaywall = true
            haptic(.light)
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkles")
                        .font(.body)
                        .foregroundColor(.accentColor)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Smart Matching")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text("Get personalized picks based on your taste")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // CTA
                Text("Try Free")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Smart Match Banner (Plus Users)
    
    private var smartMatchBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.subheadline)
                .foregroundColor(.accentColor)
            
            Text("Smart matching enabled")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { vm.useSmartMode },
                set: { vm.useSmartMode = $0 }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
            .labelsHidden()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Movie Content
    
    private var movieContent: some View {
        Group {
            if vm.isLoading && vm.movies.isEmpty {
                loadingState
            } else if let error = vm.errorMessage, vm.movies.isEmpty {
                errorState(error)
            } else if vm.displayedMovies.isEmpty {
                emptyState
            } else {
                movieGrid
            }
        }
    }
    
    private var movieGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 16
        ) {
            ForEach(Array(vm.displayedMovies.enumerated()), id: \.element.id) { index, movie in
                Button {
                    selectedMovie = movie
                    haptic(.light)
                } label: {
                    MovieDiscoverCard(
                        movie: movie,
                        vm: vm,
                        showMatchScore: entitlements.isPlus && vm.mode == .forYou
                    )
                }
                .buttonStyle(.ffPressable)
                
                // Insert upsell card after every 6 movies for free users
                if !entitlements.isPlus && (index + 1) % 6 == 0 && index < vm.displayedMovies.count - 1 {
                    inlineUpsellCard
                }
            }
            
            // Load more trigger
            if vm.hasMorePages {
                Color.clear
                    .frame(height: 50)
                    .onAppear {
                        vm.loadNextPage()
                    }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
    }
    
    // MARK: - Inline Upsell Card (Natural Discovery Moment)
    
    private var inlineUpsellCard: some View {
        Button {
            showingPlusPaywall = true
            haptic(.light)
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.3), .accentColor.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "wand.and.stars")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                
                Text("Finding the right movie?")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                
                Text("Get personalized recommendations")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Try FilmFuel+")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.accentColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.1)
            Text("Finding movies...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 300)
    }
    
    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                vm.loadInitial()
            } label: {
                Text("Try Again")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(minHeight: 300)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No movies found")
                .font(.headline)
            
            Text("Try adjusting your filters")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                vm.clearFilters()
            } label: {
                Text("Clear Filters")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(minHeight: 300)
    }
    
    // MARK: - Toolbar

    private var trailingButtons: some View {
        HStack(spacing: 16) {
            // Plus badge or upgrade button
            if entitlements.isPlus {
                Image(systemName: "checkmark.seal.fill")
                    .font(.body)
                    .foregroundColor(.accentColor)
            } else {
                Button {
                    showingPlusPaywall = true
                } label: {
                    Text("Plus")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    // MARK: - Helpers

    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(type)
        #endif
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }
}

// MARK: - Movie Discover Card

struct MovieDiscoverCard: View {
    let movie: TMDBMovie
    @ObservedObject var vm: DiscoverVM
    let showMatchScore: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster
            ZStack(alignment: .topLeading) {
                AsyncImage(url: movie.posterURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color(.secondarySystemBackground))
                            .aspectRatio(2/3, contentMode: .fit)
                            .overlay { ProgressView() }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(2/3, contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(Color(.secondarySystemBackground))
                            .aspectRatio(2/3, contentMode: .fit)
                            .overlay {
                                Image(systemName: "film")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                    @unknown default:
                        Rectangle()
                            .fill(Color(.secondarySystemBackground))
                            .aspectRatio(2/3, contentMode: .fit)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                // Top badges row
                HStack {
                    // Watchlist indicator
                    if vm.isInWatchlist(movie) {
                        Image(systemName: "bookmark.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Rating or Match score
                    if showMatchScore {
                        // Smart Match score for Plus users
                        Text("92%")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .clipShape(Capsule())
                    } else if movie.voteAverage > 0 {
                        // Regular rating
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                            Text(String(format: "%.1f", movie.voteAverage))
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                }
                .padding(8)
            }
            
            // Title
            Text(movie.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Year
            if let year = movie.releaseDate?.prefix(4) {
                Text(String(year))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let movie: TMDBMovie
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: movie.posterURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(2/3, contentMode: .fill)
                default:
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                }
            }
            .frame(width: 50, height: 75)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    if let year = movie.releaseDate?.prefix(4) {
                        Text(String(year))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if movie.voteAverage > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", movie.voteAverage))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    DiscoverView()
        .environmentObject(DiscoverVM())
        .environmentObject(FilmFuelStore())
        .environmentObject(FilmFuelEntitlements())
}
