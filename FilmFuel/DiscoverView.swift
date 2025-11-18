//
//  DiscoverView.swift
//  FilmFuel
//

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Simple favorites store (local, persisted)
private enum FavoriteStore {
    private static let key = "ff.discover.favorites"

    static func load() -> Set<String> {
        if let data = UserDefaults.standard.array(forKey: key) as? [String] {
            return Set(data)
        }
        return []
    }

    static func save(_ set: Set<String>) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

// MARK: - ViewModel (random feed + sort + async meta)
@MainActor
final class DiscoverVM: ObservableObject {
    enum Sort: String, CaseIterable, Identifiable {
        case random, titleAZ, yearDesc, imdbDesc, rtDesc

        var id: String { rawValue }
        var label: String {
            switch self {
            case .random:   return "Random"
            case .titleAZ:  return "Title A–Z"
            case .yearDesc: return "Year ↓"
            case .imdbDesc: return "IMDb ↓"
            case .rtDesc:   return "RT ↓"
            }
        }
    }

    @Published var quotes: [Quote] = []
    @Published var metas: [String: MovieMeta] = [:]   // key: movie|year|text
    @Published var sort: Sort = .random

    private let provider: MovieMetaProvider
    private let repo: QuotesRepository

    // avoid hammering OMDb
    private var inFlight: Set<String> = []
    private let maxConcurrentFetches = 2

    // endless feed extension guard
    private var isExtending = false

    init(provider: MovieMetaProvider, repo: QuotesRepository) {
        self.provider = provider
        self.repo = repo
    }

    func load(seed: Quote?) {
        let all = repo.quotes
        if !all.isEmpty {
            quotes = all.shuffled()
        } else if let seed {
            quotes = [seed]
        }

        var changed = false
        for q in quotes {
            let id = key(for: q)
            if metas[id] == nil {
                metas[id] = MovieMeta(
                    ratingText: "–",
                    funFact: "",
                    summary: "__LOADING__",
                    rtTomatometer: nil,
                    metacritic: nil
                )
                changed = true
            }
        }
        if changed { metas = metas }
    }

    func ensureMeta(for q: Quote) async {
        let id = key(for: q)

        // already loaded?
        if let m = metas[id], m.summary != "__LOADING__" {
            return
        }
        // throttle + dedupe
        if inFlight.count >= maxConcurrentFetches { return }
        if inFlight.contains(id) { return }

        inFlight.insert(id)
        defer { inFlight.remove(id) }

        let meta = await provider.meta(
            for: q.movie,
            year: q.year,
            fallbackFunFact: ""
        )

        metas[id] = meta
        metas = metas

        if sort != .random {
            applySort()
        }
    }

    func reshuffle() {
        quotes.shuffle()
    }

    func applySort() {
        switch sort {
        case .random:
            quotes.shuffle()
        case .titleAZ:
            quotes.sort { $0.movie.localizedCaseInsensitiveCompare($1.movie) == .orderedAscending }
        case .yearDesc:
            quotes.sort { $0.year > $1.year }
        case .imdbDesc:
            quotes.sort { imdb(for: $0) > imdb(for: $1) }
        case .rtDesc:
            quotes.sort { rt(for: $0) > rt(for: $1) }
        }
    }

    /// When the user scrolls near the end, append another shuffled batch
    func extendIfNeeded(currentIndex: Int) {
        guard !quotes.isEmpty else { return }
        let thresholdIndex = max(quotes.count - 3, 0)
        guard currentIndex >= thresholdIndex else { return }
        guard !isExtending else { return }
        guard !repo.quotes.isEmpty else { return }

        isExtending = true
        let extra = repo.quotes.shuffled()
        quotes.append(contentsOf: extra)
        isExtending = false
    }

    // MARK: - Helpers

    func key(for q: Quote) -> String { "\(q.movie)|\(q.year)|\(q.text)" }

    private func imdb(for q: Quote) -> Double {
        Double(metas[key(for: q)]?.ratingText ?? "") ?? -1
    }

    private func rt(for q: Quote) -> Double {
        guard let txt = metas[key(for: q)]?.rtTomatometer else { return -1 }
        return Double(txt.replacingOccurrences(of: "%", with: "")) ?? -1
    }
}

// MARK: - MAIN VIEW
struct DiscoverView: View {
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var vm = DiscoverVM(
        provider: OMDbMovieMetaProvider(),
        repo: QuotesRepository(jsonFileName: "quotes")
    )

    @State private var favorites: Set<String> = FavoriteStore.load()
    @State private var showSavedToast = false

    var body: some View {
        let items: [(key: String, quote: Quote)] = vm.quotes.map { (vm.key(for: $0), $0) }

        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.key) { idx, item in
                    let key = item.key
                    let q   = item.quote

                    DiscoverCard(
                        quote: q,
                        meta: vm.metas[key],
                        isFavorite: favorites.contains(key),
                        index: idx + 1,
                        totalCount: items.count,
                        onToggleFavorite: {
                            // Determine if this action is saving or unsaving
                            let isSaving = !favorites.contains(key)

                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                if favorites.contains(key) {
                                    favorites.remove(key)
                                } else {
                                    favorites.insert(key)
                                }
                                FavoriteStore.save(favorites)
                            }
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif

                            // Show toast only on save
                            if isSaving {
                                showSavedToast = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation(.easeOut) {
                                        showSavedToast = false
                                    }
                                }
                            }
                        },
                        onShare: { share(q) }
                    )
                    .onAppear {
                        // prefetch meta for this + next
                        Task { await vm.ensureMeta(for: q) }
                        if idx + 1 < items.count {
                            let next = items[idx + 1].quote
                            Task { await vm.ensureMeta(for: next) }
                        }

                        // 🔁 Extend deck when near the end to allow continuous scrolling
                        vm.extendIfNeeded(currentIndex: idx)
                    }
                    .containerRelativeFrame(.vertical)  // full-screen page
                    .id(key)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .bottom)
        // Toast overlay at bottom
        .overlay(alignment: .bottom) {
            if showSavedToast {
                SavedToast()
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationTitle("Discover")
        .toolbar {

            // LEFT: Saved Quotes shortcut
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink {
                    FavoritesScreen()
                        .environmentObject(appModel)
                } label: {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)
                        .imageScale(.large)
                }
            }

            // RIGHT: Sort + Shuffle
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Sort", selection: $vm.sort) {
                        ForEach(DiscoverVM.Sort.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    // iOS 17-style onChange (two-parameter closure – no deprecation)
                    .onChange(of: vm.sort) { _, _ in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            vm.applySort()
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                }

                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                        vm.reshuffle()
                    }
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    #endif
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                }
            }
        }
        .onAppear {
            // Reload favorites whenever Discover becomes visible
            favorites = FavoriteStore.load()

            if vm.quotes.isEmpty {
                vm.load(seed: appModel.todayQuote)
            }
        }
    }

    private func share(_ q: Quote) {
        #if canImport(UIKit)
        let txt = "“\(q.text)” — \(q.movie) (\(q.year)) #FilmFuel"
        let av = UIActivityViewController(activityItems: [txt], applicationActivities: nil)

        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = scene.windows.first(where: { $0.isKeyWindow }),
           let root = window.rootViewController {
            root.present(av, animated: true)
        }
        #endif
    }
}

// MARK: - One full-screen card (TikTok-style, but centered & comfy)
private struct DiscoverCard: View {
    let quote: Quote
    let meta: MovieMeta?

    var isFavorite: Bool
    var index: Int
    var totalCount: Int
    var onToggleFavorite: () -> Void
    var onShare: () -> Void

    @State private var showFavoriteFlash: Bool = false
    @State private var showMoreDetails: Bool = false

    @Environment(\.openURL) private var openURL

    // MARK: - Derived text / colors

    /// Always use fun fact from JSON, never from meta
    private var funFactText: String {
        if let raw = quote.funFact?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty {
            return raw
        }
        return "Cinema tidbit coming soon."
    }

    private var summaryText: String {
        let s = meta?.summary ?? "Loading…"
        return s == "__LOADING__" ? "Loading…" : s
    }

    private var imdbNumeric: Double? {
        Double(meta?.ratingText ?? "")
    }

    private var rtNumeric: Int? {
        guard let txt = meta?.rtTomatometer else { return nil }
        let stripped = txt.replacingOccurrences(of: "%", with: "")
        return Int(stripped)
    }

    private var accentColor: Color {
        if let rating = imdbNumeric {
            switch rating {
            case 8.5...: return .green
            case 7.5...: return .orange
            default:     return .blue.opacity(0.7)
            }
        }
        return .blue.opacity(0.7)
    }

    private func eraTag(for year: Int) -> String? {
        switch year {
        case ..<1980:      return "Classic"
        case 1980..<2005:  return "Throwback"
        case 2005...:      return "Modern"
        default:           return nil
        }
    }

    private var isFanFavorite: Bool {
        if let r = imdbNumeric {
            return r >= 8.5
        }
        return false
    }

    /// IMDb search URL for this movie
    private var imdbURL: URL? {
        let query = "\(quote.movie) \(quote.year)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "https://www.imdb.com/find/?q=\(encoded)&s=tt")
    }

    /// Rotten Tomatoes search URL for this movie
    private var rtURL: URL? {
        let query = quote.movie
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "https://www.rottentomatoes.com/search?search=\(encoded)")
    }

    var body: some View {
        GeometryReader { geo in
            // Subtle 3D tilt + scale based on vertical position
            let frame = geo.frame(in: .global)
            #if canImport(UIKit)
            let screenHeight = UIScreen.main.bounds.height
            #else
            let screenHeight = frame.height
            #endif

            let distanceFromCenter = abs(screenHeight / 2 - frame.midY)
            let normalized = min(distanceFromCenter / screenHeight, 1)
            let scale = 1 - normalized * 0.08
            let tiltAngle = Angle(degrees: Double((screenHeight / 2 - frame.midY) / screenHeight) * 6.0)

            let safeBottom = geo.safeAreaInsets.bottom
            let verticalPad: CGFloat = geo.size.height < 700 ? 12 : 20

            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(accentColor.opacity(0.35), lineWidth: 1.3)
                    )
                    .shadow(radius: 12, y: 8)

                // MAIN CONTENT (starts near top)
                VStack(spacing: 18) {
                    // Top: position / movie / tags
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(index)/\(totalCount)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial, in: Capsule())

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(quote.movie)
                                .font(.title2.weight(.semibold))
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)

                            Text(String(quote.year))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            // Highlight strip: era + fan favorite tag
                            HStack(spacing: 6) {
                                if let tag = eraTag(for: quote.year) {
                                    TagPill(text: tag, systemImage: "clock.arrow.circlepath")
                                }
                                if isFanFavorite {
                                    TagPill(text: "Fan Favorite", systemImage: "flame.fill")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                    // Quote card + context menu
                    Text("“\(quote.text)”")
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(7)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.secondarySystemBackground).opacity(0.9))
                        )
                        .padding(.horizontal, 18)
                        .contextMenu {
                            Button {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = "\"\(quote.text)\" — \(quote.movie) (\(quote.year))"
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                            } label: {
                                Label("Copy with movie", systemImage: "doc.on.doc")
                            }

                            Button {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = quote.text
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                            } label: {
                                Label("Copy quote only", systemImage: "quote.bubble")
                            }

                            Button {
                                triggerFavoriteToggle()
                            } label: {
                                Label(isFavorite ? "Unsave quote" : "Save quote",
                                      systemImage: isFavorite ? "heart.slash" : "heart")
                            }
                        }

                    // Ratings strip (simple chips)
                    HStack(spacing: 8) {
                        Chip(icon: "star.fill", text: "IMDb \(meta?.ratingText ?? "–")")
                        if let rt = meta?.rtTomatometer {
                            Chip(icon: "percent", text: "RT \(rt)")
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18)

                    // Info sections
                    VStack(alignment: .leading, spacing: 14) {
                        // Fun Fact
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Fun Fact", systemImage: "lightbulb")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(accentColor)
                            Text(funFactText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }

                        Divider().opacity(0.2)

                        // Summary
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Summary", systemImage: "text.justify.left")
                                .font(.footnote.weight(.semibold))
                            Text(summaryText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }

                        // Expandable "More about this movie"
                        if imdbURL != nil || rtURL != nil || imdbNumeric != nil || rtNumeric != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        showMoreDetails.toggle()
                                    }
                                    #if canImport(UIKit)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    #endif
                                } label: {
                                    HStack(spacing: 6) {
                                        Text("More about this movie")
                                        Spacer()
                                        Image(systemName: showMoreDetails ? "chevron.up" : "chevron.down")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }

                                if showMoreDetails {
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Ratings summary line
                                        if imdbNumeric != nil || rtNumeric != nil || meta?.metacritic != nil {
                                            HStack(spacing: 8) {
                                                if let imdb = imdbNumeric {
                                                    Label(String(format: "IMDb %.1f", imdb), systemImage: "star.fill")
                                                }
                                                if let rt = rtNumeric {
                                                    Label("RT \(rt)%", systemImage: "percent")
                                                }
                                                if let m = meta?.metacritic {
                                                    Label("MC \(m)", systemImage: "chart.bar.fill")
                                                }
                                            }
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        }

                                        // Branded IMDb / Rotten buttons
                                        HStack(spacing: 10) {
                                            if let url = imdbURL {
                                                Button {
                                                    #if canImport(UIKit)
                                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                    #endif
                                                    openURL(url)
                                                } label: {
                                                    HStack(spacing: 6) {
                                                        Text("IMDb")
                                                            .fontWeight(.heavy)
                                                        Image(systemName: "arrow.up.right")
                                                    }
                                                    .font(.caption.weight(.semibold))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                            .fill(Color(red: 245/255, green: 197/255, blue: 24/255))
                                                    )
                                                    .foregroundStyle(Color.black)
                                                }
                                            }

                                            if let url = rtURL {
                                                Button {
                                                    #if canImport(UIKit)
                                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                    #endif
                                                    openURL(url)
                                                } label: {
                                                    HStack(spacing: 6) {
                                                        Text("Rotten Tomatoes")
                                                            .fontWeight(.semibold)
                                                        Image(systemName: "arrow.up.right")
                                                    }
                                                    .font(.caption.weight(.semibold))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                            .fill(Color.red.opacity(0.9))
                                                    )
                                                    .foregroundStyle(Color.white)
                                                }
                                            }
                                        }
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.vertical, verticalPad)

                // RIGHT ACTION RAIL (Save / Share) ABOVE BOTTOM NAV
                VStack(spacing: 24) {
                    Spacer()

                    Button(action: {
                        triggerFavoriteToggle()
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 24))
                            Text(isFavorite ? "Saved" : "Save")
                                .font(.caption2)
                        }
                        .padding(14)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .shadow(radius: 6, y: 3)
                        )
                    }
                    .tint(isFavorite ? .red : .primary)

                    Button(action: onShare) {
                        VStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 24))
                            Text("Share")
                                .font(.caption2)
                        }
                        .padding(14)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .shadow(radius: 6, y: 3)
                        )
                    }

                    // Buttons kept higher than original (safeBottom + 44)
                    Spacer().frame(height: safeBottom + 44)
                }
                .padding(.trailing, 24)
                .frame(maxWidth: .infinity, alignment: .trailing)

                // Favorite flash overlay
                if showFavoriteFlash {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Color.red.opacity(0.7), lineWidth: 3)
                        .shadow(color: .red.opacity(0.25), radius: 16, y: 8)
                        .padding(4)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, verticalPad)
            .frame(width: geo.size.width, height: geo.size.height)
            .scaleEffect(scale)
            .rotation3DEffect(tiltAngle, axis: (x: 1, y: 0, z: 0))
            // Double-tap anywhere on the card to favorite
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                triggerFavoriteToggle()
            }
        }
    }

    // Shared logic for heart button + double-tap + context menu save
    private func triggerFavoriteToggle() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
            onToggleFavorite()
            showFavoriteFlash = true
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut) {
                showFavoriteFlash = false
            }
        }
    }
}

// MARK: - Highlight pill
private struct TagPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
    }
}

// MARK: - Small reusable rating chip
private struct Chip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text).monospacedDigit()
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }
}

// MARK: - Saved toast
private struct SavedToast: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text("Saved to Favorites")
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 8, y: 4)
    }
}
