//
//  MovieDetailView.swift
//  FilmFuel
//
//  UPDATED: Better hero section, improved actions, expandable overview,
//  visual rating ring, cleaner sections, share button, enhanced "More Like This"
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
    
    // Expandable overview
    @State private var isOverviewExpanded = false
    
    // Animation states
    @State private var animateHeader = false
    @State private var animateContent = false

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
            VStack(spacing: 0) {
                headerImageSection
                
                VStack(alignment: .leading, spacing: 16) {
                    // Quick actions bar (floating style)
                    quickActionsBar
                        .padding(.top, -24) // Overlap with header
                    
                    // Info section
                    infoSection
                    
                    // Watch context (Good For)
                    watchContextSection
                    
                    // Smart Match section
                    smartMatchSection
                    
                    // Smart Insights
                    smartInsightsSection
                    
                    // Overview with expand/collapse
                    overviewSection
                    
                    // Genres
                    genresSection
                    
                    // Where to watch
                    whereToWatchSection
                    
                    // Plus upsell
                    plusUpsellSection
                    
                    // More like this
                    moreLikeThisSection
                    
                    // Taste training toast
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                shareButton
            }
        }
        .task {
            await vm.loadIfNeeded()
            discoverVM.recordDetailOpen(movie)
            
            // Stagger animations
            withAnimation(.easeOut(duration: 0.5)) {
                animateHeader = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                animateContent = true
            }
        }
        .overlay(alignment: .center) {
            if vm.isLoading && vm.detail == nil && vm.errorMessage == nil {
                ProgressView()
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .alert("Couldn't load movie details", isPresented: Binding(
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

    // MARK: - Share Button
    
    private var shareButton: some View {
        ShareLink(
            item: "Check out \(vm.displayTitle) on FilmFuel!",
            subject: Text(vm.displayTitle),
            message: Text("I found this on FilmFuel and thought you might like it!")
        ) {
            Image(systemName: "square.and.arrow.up")
                .font(.body.weight(.medium))
        }
    }

    // MARK: - Header Hero Image

    private var headerImageSection: some View {
        ZStack(alignment: .bottom) {
            // Background image
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
                        Color.clear,
                        Color(.systemBackground).opacity(0.5),
                        Color(.systemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Title card overlay
            VStack(alignment: .leading, spacing: 8) {
                Text(vm.displayTitle)
                    .font(.title.weight(.bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 10) {
                    // Year badge
                    if vm.displayYearText != "—" {
                        metaBadge(text: vm.displayYearText, icon: nil)
                    }
                    
                    // Runtime badge
                    if let runtimeText = vm.runtimeText {
                        metaBadge(text: runtimeText, icon: "clock")
                    }

                    // Rating badge
                    if let cert = vm.certification, !cert.isEmpty {
                        metaBadge(text: cert, icon: nil)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
            .opacity(animateHeader ? 1 : 0)
            .offset(y: animateHeader ? 0 : 20)
        }
    }
    
    private func metaBadge(text: String, icon: String?) -> some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }

    // MARK: - Quick Actions Bar
    
    private var quickActionsBar: some View {
        let isInWatchlist = discoverVM.isInWatchlist(movie)
        let isSeen = discoverVM.isSeen(movie)
        let isDisliked = discoverVM.isDisliked(movie)

        return HStack(spacing: 0) {
            // Watchlist
            actionButton(
                icon: isInWatchlist ? "bookmark.fill" : "bookmark",
                label: "Watchlist",
                isActive: isInWatchlist,
                activeColor: .accentColor
            ) {
                discoverVM.toggleWatchlist(movie)
                hapticFeedback(.light)
            }
            
            Divider()
                .frame(height: 32)
            
            // Seen
            actionButton(
                icon: isSeen ? "eye.fill" : "eye",
                label: "Seen",
                isActive: isSeen,
                activeColor: .green
            ) {
                discoverVM.toggleSeen(movie)
                hapticFeedback(.rigid)
            }
            
            Divider()
                .frame(height: 32)
            
            // Not for me
            actionButton(
                icon: isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                label: "Skip",
                isActive: isDisliked,
                activeColor: .red
            ) {
                discoverVM.toggleDisliked(movie)
                hapticFeedback(.medium)
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        )
        .opacity(animateContent ? 1 : 0)
        .scaleEffect(animateContent ? 1 : 0.95)
    }
    
    private func actionButton(
        icon: String,
        label: String,
        isActive: Bool,
        activeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isActive ? activeColor : .primary)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(isActive ? activeColor : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Info Section (Rating + Meta)
    
    private var infoSection: some View {
        HStack(spacing: 12) {
            // Rating ring
            ratingRing
            
            VStack(alignment: .leading, spacing: 4) {
                // Tagline if available
                if let d = vm.detail,
                   let taglineRaw = d.tagline,
                   !taglineRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(taglineRaw)
                        .font(.subheadline.italic())
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Vote count
                if vm.displayVoteCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.3.fill")
                            .font(.caption2)
                        Text("\(vm.formattedVoteCount) ratings")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                // Certification badge (if loaded)
                if let cert = vm.certification {
                    HStack(spacing: 4) {
                        Text(cert)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Capsule())
                    }
                }
                
                // Taste training button
                let hasDetailGenres = (vm.detail?.genres.isEmpty == false)
                let hasBaseGenres = (movie.genreIDs?.isEmpty == false)
                
                if hasDetailGenres || hasBaseGenres {
                    trainTasteButton
                }
            }
            
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .opacity(animateContent ? 1 : 0)
    }
    
    // MARK: - Watch Context Section
    
    private var watchContextSection: some View {
        Group {
            let contexts = vm.watchContexts
            if !contexts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Good For")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(contexts, id: \.rawValue) { context in
                                HStack(spacing: 6) {
                                    Image(systemName: context.icon)
                                        .font(.caption)
                                    Text(context.rawValue)
                                        .font(.caption.weight(.medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var ratingRing: some View {
        let rating = vm.displayVoteAverage
        let progress = rating / 10.0
        let ratingColor = ratingColor(for: rating)
        
        return ZStack {
            // Background ring
            Circle()
                .stroke(ratingColor.opacity(0.2), lineWidth: 5)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ratingColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            // Rating text
            VStack(spacing: 0) {
                Text(String(format: "%.1f", rating))
                    .font(.headline.weight(.bold))
                Text("/ 10")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 60, height: 60)
    }
    
    private func ratingColor(for rating: Double) -> Color {
        if rating >= 7.5 {
            return .green
        } else if rating >= 5.5 {
            return .yellow
        } else {
            return .red
        }
    }

    // MARK: - Taste Training Button
    
    private var trainTasteButton: some View {
        let isPlus = entitlements.isPlus

        return Button {
            discoverVM.trainTaste(on: movie, isStrong: isPlus)
            hapticFeedback(.soft)

            if isPlus {
                tasteToastText = "Boosted: FilmFuel+ will lean harder into picks like this."
            } else {
                tasteToastText = "Got it — we'll lean more into movies like this."
            }

            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showTasteToast = true
            }

            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showTasteToast = false
                    }
                }
            }

        } label: {
            HStack(spacing: 6) {
                Image(systemName: isPlus ? "sparkles" : "slider.horizontal.3")
                    .font(.caption)
                Text(isPlus ? "Boost taste" : "Train taste")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
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
                .foregroundColor(.green)
            Text(tasteToastText)
                .font(.footnote)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
    }

    // MARK: - Smart Match Section

    private var smartMatchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .foregroundColor(.accentColor)
                    Text("Smart Match")
                        .font(.headline)
                }
                
                Spacer()

                // Score badge with tier color
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(vm.smartMatchScore)%")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(vm.smartMatchTier.color.gradient)
                        )
                    
                    Text(vm.smartMatchTier.label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Reasons
            VStack(alignment: .leading, spacing: 6) {
                let reasons = vm.smartReasonLines
                if entitlements.isPlus {
                    ForEach(reasons, id: \.self) { line in
                        reasonRow(line)
                    }
                } else {
                    if let first = reasons.first {
                        reasonRow(first)
                    }
                    if reasons.count > 1 {
                        Button {
                            showingPlusPaywall = true
                            hapticFeedback(.light)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                Text("See \(reasons.count - 1) more reasons with FilmFuel+")
                                    .font(.caption)
                            }
                            .foregroundColor(.accentColor)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func reasonRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
                .padding(.top, 2)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Smart Insights Section

    private var smartInsightsSection: some View {
        let chips = vm.quickInsights
        guard !chips.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("Smart Insights")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    if !entitlements.isPlus {
                        Text("Plus")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.18))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if entitlements.isPlus {
                            ForEach(chips, id: \.self) { chip in
                                insightChip(text: chip, style: .highlighted)
                            }
                        } else {
                            if let first = chips.first {
                                insightChip(text: first, style: .normal)
                            }
                            if chips.count > 1 {
                                Button {
                                    showingPlusPaywall = true
                                    hapticFeedback(.light)
                                } label: {
                                    insightChip(
                                        text: "+\(chips.count - 1) more",
                                        style: .locked
                                    )
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        )
    }
    
    private enum ChipStyle {
        case normal, highlighted, locked
    }

    private func insightChip(text: String, style: ChipStyle) -> some View {
        HStack(spacing: 4) {
            if style == .locked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
            }
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Group {
                switch style {
                case .normal:
                    Color(.tertiarySystemBackground)
                case .highlighted:
                    Color.accentColor.opacity(0.18)
                case .locked:
                    Color.accentColor.opacity(0.12)
                }
            }
        )
        .foregroundColor(style == .normal ? .primary : .accentColor)
        .clipShape(Capsule())
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        Group {
            if let overview = vm.overviewText {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Overview")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(overview)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(isOverviewExpanded ? nil : 4)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Show expand button if text is long
                        if overview.count > 200 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isOverviewExpanded.toggle()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(isOverviewExpanded ? "Show less" : "Read more")
                                    Image(systemName: isOverviewExpanded ? "chevron.up" : "chevron.down")
                                        .font(.caption2)
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Genres Section
    
    private var genresSection: some View {
        Group {
            if let d = vm.detail {
                let genres = d.genres
                if !genres.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Genres")
                            .font(.headline)

                        FlexibleGenreChips(genres: genres)
                    }
                }
            }
        }
    }

    // MARK: - Where to Watch Section

    private var whereToWatchSection: some View {
        Group {
            if !vm.watchProviders.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Where to Watch")
                            .font(.headline)
                        
                        Spacer()
                        
                        if let region = vm.watchProvidersRegion {
                            Text(region)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(vm.watchProviders) { provider in
                                providerChip(provider: provider)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    if let url = vm.whereToWatchURL {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Text("See all options on TMDB")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }
            } else if let url = vm.whereToWatchURL {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Where to Watch")
                        .font(.headline)

                    Link(destination: url) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.tv")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Check availability")
                                    .font(.subheadline.weight(.medium))
                                Text("See streaming options on TMDB")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func providerChip(provider: MovieWatchProvider) -> some View {
        HStack(spacing: 6) {
            // Provider logo placeholder (could use actual logo if available)
            Image(systemName: "tv")
                .font(.caption)
                .foregroundColor(.accentColor)
            Text(provider.name)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }

    // MARK: - Plus Upsell Section

    private var plusUpsellSection: some View {
        Group {
            if !entitlements.isPlus {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Get more from FilmFuel")
                                .font(.headline)
                            Text("Unlock full Smart Match breakdowns, all insights, and boosted recommendations.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button {
                        showingPlusPaywall = true
                        hapticFeedback(.medium)
                    } label: {
                        HStack {
                            Text("Upgrade to FilmFuel+")
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: - More Like This Section

    private var moreLikeThisSection: some View {
        Group {
            // Prefer TMDB recommendations if available
            let recs = vm.recommendations.isEmpty ? localRecommendations : vm.recommendations
            
            if !recs.isEmpty || vm.isLoadingRecommendations {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("More Like This")
                            .font(.headline)
                        
                        Spacer()
                        
                        if vm.isLoadingRecommendations {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("\(recs.count) movies")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if vm.isLoadingRecommendations && recs.isEmpty {
                        // Skeleton loading state
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(0..<4, id: \.self) { _ in
                                    skeletonCard
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(recs) { rec in
                                    NavigationLink {
                                        MovieDetailView(movie: rec)
                                            .environmentObject(discoverVM)
                                            .environmentObject(entitlements)
                                            .environmentObject(store)
                                    } label: {
                                        recommendationCard(movie: rec)
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
    }
    
    // Fallback to local filtering if TMDB recommendations fail
    private var localRecommendations: [TMDBMovie] {
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

        return Array(sorted.prefix(10).map { $0.0 })
    }
    
    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .frame(width: 110, height: 165)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.tertiarySystemBackground))
                .frame(width: 100, height: 12)
        }
        .redacted(reason: .placeholder)
    }
    
    private func recommendationCard(movie: TMDBMovie) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: movie.posterURL) { phase in
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
                
                // Rating badge
                if movie.voteAverage > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text(String(format: "%.1f", movie.voteAverage))
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Capsule())
                    .padding(6)
                }
            }

            Text(movie.title)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 110, alignment: .leading)
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
    
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }
}

// MARK: - Flexible Genre Chips

private struct FlexibleGenreChips: View {
    let genres: [TMDBGenre]

    var body: some View {
        FlexibleChipsLayout {
            ForEach(genres) { genre in
                Text(genre.name)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
            }
        }
    }
}

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

#Preview {
    NavigationStack {
        MovieDetailView(
            movie: TMDBMovie(
                id: 550,
                title: "Fight Club",
                overview: "A depressed man suffering from insomnia meets a strange soap salesman named Tyler Durden and soon finds himself living in his squalid house after his perfect apartment is destroyed.",
                posterPath: nil,
                backdropPath: nil,
                releaseDate: "1999-10-15",
                voteAverage: 8.4,
                voteCount: 26000,
                genreIDs: [18, 53]
            )
        )
        .environmentObject(DiscoverVM(client: TMDBClient()))
        .environmentObject(FilmFuelEntitlements())
        .environmentObject(FilmFuelStore())
    }
}
