import WidgetKit
import SwiftUI


// MARK: - QuoteStore

final class QuoteStore {
    static let shared = QuoteStore()
    private(set) var quotes: [Quote] = []

    init() {
        // Load quotes.json from bundle shared by app + widget target membership
        if let url = Bundle.main.url(forResource: "quotes", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Quote].self, from: data) {
            self.quotes = decoded
        }
    }
}

// MARK: - Daily selection (deterministic + cached)

struct DailyQuoteSelector {
    // Use your App Group identifier here
    static let suiteName = "group.com.chrisolah.FilmFuel"
    static let cacheKey = "FilmFuel.today.entry"

    struct CachedEntry: Codable {
        let yyyymmdd: String
        let index: Int
    }

    static func todayString(for date: Date = Date(), in tz: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
    }

    static func rolloverDate(from date: Date = Date(), hour: Int = 3, tz: TimeZone = .current) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let startOfDay = cal.startOfDay(for: date)
        return cal.date(byAdding: .hour, value: (date < cal.date(byAdding: .hour, value: hour, to: startOfDay)!) ? hour : 24 + hour, to: startOfDay)!
    }

    static func deterministicIndex(for date: Date, count: Int) -> Int {
        // No randomness: use days since a reference date
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let ref = Date(timeIntervalSince1970: 0)
        let days = cal.dateComponents([.day], from: ref, to: date).day ?? 0
        return count == 0 ? 0 : abs(days) % count
    }

    static func entryForToday(quotes: [Quote], now: Date = Date()) -> (Quote, Date) {
        let defaults = UserDefaults(suiteName: suiteName)!
        let today = todayString(for: now)
        if let data = defaults.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(CachedEntry.self, from: data),
           cached.yyyymmdd == today,
           cached.index < quotes.count {
            return (quotes[cached.index], rolloverDate(from: now))
        }

        let idx: Int
        // If your JSON has explicit dates, you can try match first:
        if let matchIndex = quotes.firstIndex(where: { $0.date == today }) {
            idx = matchIndex
        } else {
            idx = deterministicIndex(for: now, count: quotes.count)
        }

        let cache = CachedEntry(yyyymmdd: today, index: idx)
        if let data = try? JSONEncoder().encode(cache) {
            defaults.set(data, forKey: cacheKey)
        }
        return (quotes[idx], rolloverDate(from: now))
    }
}

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), quote: QuoteStore.shared.quotes.first ?? placeholderQuote())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let (q, _) = DailyQuoteSelector.entryForToday(quotes: QuoteStore.shared.quotes, now: Date())
        completion(SimpleEntry(date: Date(), quote: q))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let now = Date()
        let (q, next) = DailyQuoteSelector.entryForToday(quotes: QuoteStore.shared.quotes, now: now)
        let entry = SimpleEntry(date: now, quote: q)
        // Single entry; next refresh at rollover time
        let timeline = Timeline(entries: [entry], policy: .after(next))
        completion(timeline)
    }

    private func placeholderQuote() -> Quote {
        Quote(
            date: DailyClock.currentDayKey(),
            text: "Hope is a good thing...",
            movie: "The Shawshank Redemption",
            year: 1994,
            trivia: Trivia(
                question: "Which real prison was used for Shawshank’s exterior/interiors?",
                choices: ["Ohio State Reformatory","Joliet Correctional Center","Eastern State Penitentiary","Sing Sing Correctional Facility"],
                correctIndex: 0
            )
        )
    }

}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let quote: Quote
}

// MARK: - Widget

@main
struct FilmFuelWidget: Widget {
    let kind: String = "FilmFuelWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            FilmFuelWidgetView(entry: entry)
                // iOS 17+ background for widgets
                .containerBackground(for: .widget) {
                    // pick one:
                    Color(.systemBackground)        // safe, light/dark aware
                    // LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom)
                    // Color.clear  // lets the system provide its material
                }
                // optional: edge-to-edge content
         
        }
        .configurationDisplayName("FilmFuel")
        .description("Daily motivational movie quote.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}
