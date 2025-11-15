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
                            if favorites.contains(key) { favorites.remove(key) }
                            else { favorites.insert(key) }
                            FavoriteStore.save(favorites)
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                        },
                        onShare: { share(q) }
                    )
                    .onAppear {
                        Task { await vm.ensureMeta(for: q) }
                        if idx + 1 < items.count {
                            let next = items[idx + 1].quote
                            Task { await vm.ensureMeta(for: next) }
                        }
                    }
                    .containerRelativeFrame(.vertical)  // full-screen page
                    .id(key)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .ignoresSafeArea(edges: .bottom)
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
                    .onChange(of: vm.sort) {
                        vm.applySort()
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                }

                Button { vm.reshuffle() } label: {
                    Label("Shuffle", systemImage: "shuffle")
                }
            }
        }
        .onAppear {
            // 🔁 Reload favorites whenever Discover becomes visible
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

    var body: some View {
        GeometryReader { geo in
            let safeBottom = geo.safeAreaInsets.bottom
            let verticalPad: CGFloat = geo.size.height < 700 ? 12 : 20

            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(radius: 12, y: 8)

                // MAIN CONTENT (starts near top like original)
                VStack(spacing: 18) {
                    // Top: position / movie
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(index)/\(totalCount)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial, in: Capsule())

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(quote.movie)
                                .font(.title2.weight(.semibold))   // slightly bigger title
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                            Text(String(quote.year))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                    // Quote card
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

                    // Ratings row
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

                    Button(action: onToggleFavorite) {
                        VStack(spacing: 6) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 24))   // slightly smaller
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
                                .font(.system(size: 24))   // slightly smaller
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, verticalPad)
            .frame(width: geo.size.width, height: geo.size.height)
        }
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
