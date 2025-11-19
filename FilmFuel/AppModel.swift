import Foundation
import Combine
import UserNotifications
#if DEBUG
import WidgetKit
#endif

// MARK: - Trivia model (for all trivia packs)

struct TriviaQuestion: Identifiable, Codable, Hashable {
    let id: String
    let movieTitle: String
    let year: Int
    let genre: String?          // optional so older / simpler JSON still works
    let difficulty: String      // "easy", "normal", "challenging"
    let question: String
    let options: [String]
    let correctIndex: Int
    let extraInfo: String?
}

// Simple metadata for future pack monetization / filtering (optional but handy)
struct TriviaPack {
    let id: String            // e.g. "classics", "pixar"
    let displayName: String   // e.g. "Classics"
    let fileName: String      // base name in bundle (no .json)
    let isPremium: Bool
    var isUnlocked: Bool
}

// MARK: - Reminder preferences keys (shared)

enum Prefs {
    static let reminderHourKey = "ff.reminder.hour"
    static let reminderMinuteKey = "ff.reminder.minute"
    static let reminderModeKey = "ff.reminder.mode" // Int rawValue of ReminderContentMode
}

// MARK: - Reminder content mode (shared)

enum ReminderContentMode: Int, CaseIterable, Identifiable {
    case triviaOnly = 0
    case triviaAndQuote = 1
    case quoteOnly = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .triviaOnly: return "Trivia only"
        case .triviaAndQuote: return "Trivia + Quote"
        case .quoteOnly: return "Quote only"
        }
    }
}

// MARK: - Notifications helper (shared, canonical)

enum NotificationHelper {

    static let reminderId = "ff.daily.reminder"

    static func currentAuthorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            completion(s.authorizationStatus)
        }
    }

    static func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                completion(granted)
            }
    }

    // Preferred: accepts quote + movie
    static func scheduleDailyReminder(
        hour: Int,
        minute: Int,
        mode: ReminderContentMode,
        quote: String?,
        movie: String?,
        completion: @escaping (Bool) -> Void
    ) {
        let content = makeContent(mode: mode, quote: quote, movie: movie)

        var date = DateComponents()
        date.hour = hour
        date.minute = minute
        date.second = 0

        let trig = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let req = UNNotificationRequest(identifier: reminderId, content: content, trigger: trig)

        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderId])

        UNUserNotificationCenter.current().add(req) { err in
            completion(err == nil)
        }
    }

    // Back-compat: quote-only signature
    static func scheduleDailyReminder(
        hour: Int,
        minute: Int,
        mode: ReminderContentMode,
        quotePreview: String?,
        completion: @escaping (Bool) -> Void
    ) {
        scheduleDailyReminder(
            hour: hour,
            minute: minute,
            mode: mode,
            quote: quotePreview,
            movie: nil,
            completion: completion
        )
    }

    static func refreshDailyReminderBody(
        hour: Int,
        minute: Int,
        mode: ReminderContentMode,
        todaysQuote: String?,
        todaysMovie: String?,
        completion: @escaping (Bool) -> Void
    ) {
        scheduleDailyReminder(
            hour: hour,
            minute: minute,
            mode: mode,
            quote: todaysQuote,
            movie: todaysMovie,
            completion: completion
        )
    }

    // Back-compat refresh
    static func refreshDailyReminderBody(
        hour: Int,
        minute: Int,
        mode: ReminderContentMode,
        todaysQuote: String?,
        completion: @escaping (Bool) -> Void
    ) {
        refreshDailyReminderBody(
            hour: hour,
            minute: minute,
            mode: mode,
            todaysQuote: todaysQuote,
            todaysMovie: nil,
            completion: completion
        )
    }

    static func cancelDailyReminder(_ completion: @escaping () -> Void) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderId])
        completion()
    }

    static func isReminderScheduled(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
            completion(reqs.contains { $0.identifier == reminderId })
        }
    }

    static func sendTestNotification(after seconds: TimeInterval = 3) {
        requestPermission { granted in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "FilmFuel Test"
            content.body = "This is a test notification ✅"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, seconds),
                repeats: false
            )

            let req = UNNotificationRequest(
                identifier: "ff.test.\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
        }
    }

    // Body now supports “quote” — Movie
    private static func makeContent(
        mode: ReminderContentMode,
        quote: String?,
        movie: String?
    ) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()

        switch mode {

        case .triviaOnly:
            c.title = "FilmFuel Quiz"
            c.body = "Your daily movie quiz is ready."

        case .triviaAndQuote:
            c.title = "FilmFuel"
            if let q = quote, !q.isEmpty,
               let m = movie, !m.isEmpty {
                c.body = "“\(q)” — \(m)"
            } else if let q = quote, !q.isEmpty {
                c.body = "“\(q)”"
            } else {
                c.body = "Your quote & quiz are ready."
            }

        case .quoteOnly:
            c.title = "FilmFuel Quote"
            if let q = quote, !q.isEmpty,
               let m = movie, !m.isEmpty {
                c.body = "“\(q)” — \(m)"
            } else if let q = quote, !q.isEmpty {
                c.body = "Today’s quote: “\(q)”"
            } else {
                c.body = "Today’s quote is ready."
            }
        }

        c.sound = .default
        return c
    }
}

// MARK: - AppModel

final class AppModel: ObservableObject {

    // OLD keys (migration only)
    private let kStreak = "ff.currentStreak"
    private let kLastCompletedDay = "ff.lastCompletedDayKey"
    private let kLastSeenDay = "ff.lastSeenDayKey"

    // NEW keys
    private let kDailyStreak = "ff.dailyStreak"
    private let kCorrectStreak = "ff.correctStreak"
    private let kBestCorrectStreak = "ff.bestCorrectStreak"
    private let kLastPlayDay = "ff.lastPlayDayKey"
    private let kLastCorrectDay = "ff.lastCorrectDayKey"
    private let kLastAnsweredDay = "ff.lastAnsweredDayKey"
    private let kLastResultWasCorrect = "ff.lastResultWasCorrect"

    // Trivia keys
    private let kTriviaLastDate = "ff.trivia.lastDate"
    private let kTriviaLastQuestionID = "ff.trivia.lastQuestionID"

    private var defaults: UserDefaults { .standard }

    // UI state
    @Published var currentStreak: Int = 0
    @Published var dailyStreak: Int = 0
    @Published var correctStreak: Int = 0
    @Published var bestCorrectStreak: Int = 0
    @Published var quizCompletedToday: Bool = false

    @Published var dayKey: String = DailyClock.currentDayKey()
    @Published var showNewRecordToast: Bool = false
    @Published var lastResultWasCorrect: Bool? = nil

    @Published var todayQuote: Quote = Quote(
        date: DailyClock.currentDayKey(),
        text: "Loading…",
        movie: "",
        year: 0,
        trivia: Trivia(
            question: "",
            choices: [],
            correctIndex: 0
        )
    )

    // NEW: expose all quotes for Discover
    @Published var allQuotes: [Quote] = []

    // Trivia
    @Published var triviaBank: [TriviaQuestion] = []    // combined pool from ALL packs
    @Published var todayTrivia: TriviaQuestion?

    // For endless trivia mode (queue-style, no repeats until cycle ends)
    @Published private var endlessCursorIndex: Int = 0

    // Optional: metadata if you later want a Packs screen / monetization toggles
    private(set) var triviaPacks: [TriviaPack] = [
        TriviaPack(
            id: "classics",
            displayName: "Classics",
            fileName: "trivia_classics",
            isPremium: false,
            isUnlocked: true
        ),
        TriviaPack(
            id: "scifi",
            displayName: "Sci-Fi",
            fileName: "trivia_scifi",
            isPremium: false,
            isUnlocked: true
        ),
        TriviaPack(
            id: "pixar",
            displayName: "Pixar",
            fileName: "trivia_pixar",
            isPremium: false,
            isUnlocked: true
        ),
        TriviaPack(
            id: "nineties",
            displayName: "90s",
            fileName: "trivia_90s",
            isPremium: false,
            isUnlocked: true
        ),
        TriviaPack(
            id: "twoThousands",
            displayName: "2000s",
            fileName: "trivia_2000s",
            isPremium: false,
            isUnlocked: true
        ),
        TriviaPack(
            id: "modern",
            displayName: "Modern",
            fileName: "trivia_modern",
            isPremium: false,
            isUnlocked: true
        ),
        TriviaPack(
            id: "horror",
            displayName: "Horror",
            fileName: "trivia_horror",
            isPremium: false,
            isUnlocked: true
        ),
        TriviaPack(
            id: "nolan",
            displayName: "Christopher Nolan",
            fileName: "trivia_nolan",
            isPremium: true,
            isUnlocked: true
        ),
        TriviaPack(
            id: "tarantino",
            displayName: "Tarantino",
            fileName: "trivia_tarantino",
            isPremium: true,
            isUnlocked: true
        ),
        TriviaPack(
            id: "avengers",
            displayName: "Avengers",
            fileName: "trivia_avengers",
            isPremium: true,
            isUnlocked: true
        )
    ]

    // Data
    private let repo = QuotesRepository(jsonFileName: "quotes")

    // MARK: - Init

    init() {
        let today = DailyClock.currentDayKey()
        dayKey = today

        dailyStreak = max(0, defaults.integer(forKey: kDailyStreak))
        correctStreak = max(0, defaults.integer(forKey: kCorrectStreak))
        bestCorrectStreak = max(0, defaults.integer(forKey: kBestCorrectStreak))

        // Migration from old system
        if dailyStreak == 0 && correctStreak == 0 {
            let oldStreak = max(0, defaults.integer(forKey: kStreak))
            let oldLastCompleted = defaults.string(forKey: kLastCompletedDay) ?? ""

            if oldStreak > 0 && !oldLastCompleted.isEmpty {
                dailyStreak = oldStreak
                correctStreak = oldStreak
                bestCorrectStreak = max(bestCorrectStreak, oldStreak)

                defaults.set(dailyStreak, forKey: kDailyStreak)
                defaults.set(correctStreak, forKey: kCorrectStreak)
                defaults.set(bestCorrectStreak, forKey: kBestCorrectStreak)

                defaults.set(oldLastCompleted, forKey: kLastPlayDay)
                defaults.set(oldLastCompleted, forKey: kLastCorrectDay)
            }
        }

        currentStreak = correctStreak

        let lastAnswered = defaults.string(forKey: kLastAnsweredDay)
            ?? defaults.string(forKey: kLastCompletedDay) ?? ""

        quizCompletedToday = (lastAnswered == today)
        lastResultWasCorrect = quizCompletedToday
            ? (defaults.object(forKey: kLastResultWasCorrect) as? Bool)
            : nil

        todayQuote = repo.quote(forDayKey: today)
            ?? repo.rotatingQuote(forDayKey: today)
            ?? fallbackQuote()

        allQuotes = repo.quotes

        defaults.set(today, forKey: kLastSeenDay)

        refreshReminderIfNeededForToday()

        // Trivia setup
        loadTriviaIfNeeded()
        ensureTodayTrivia()
    }

    // MARK: - Daily refresh

    func refreshDailyStateIfNeeded() {
        let newKey = DailyClock.currentDayKey()
        guard newKey != dayKey else { return }

        dayKey = newKey

        todayQuote = repo.quote(forDayKey: newKey)
            ?? repo.rotatingQuote(forDayKey: newKey)
            ?? fallbackQuote()

        allQuotes = repo.quotes

        let lastAnswered = defaults.string(forKey: kLastAnsweredDay)
            ?? defaults.string(forKey: kLastCompletedDay) ?? ""

        quizCompletedToday = (lastAnswered == newKey)
        lastResultWasCorrect = quizCompletedToday
            ? (defaults.object(forKey: kLastResultWasCorrect) as? Bool)
            : nil

        refreshReminderIfNeededForToday()
        ensureTodayTrivia()
    }

    // MARK: - Endless trivia helper (no repeats until cycle)

    /// Returns the next trivia question for endless mode, cycling through the shuffled bank
    /// without repetition until all questions have been seen.
    func nextEndlessTriviaQuestion() -> TriviaQuestion? {
        loadTriviaIfNeeded()
        guard !triviaBank.isEmpty else { return nil }

        if endlessCursorIndex >= triviaBank.count {
            triviaBank.shuffle()
            endlessCursorIndex = 0
        }

        let q = triviaBank[endlessCursorIndex]
        endlessCursorIndex += 1
        return q
    }

    // MARK: - Trivia loading (ALL packs → one pool)

    func loadTriviaIfNeeded() {
        if !triviaBank.isEmpty { return }

        var combined: [TriviaQuestion] = []

        // Load each unlocked pack and append its questions
        for pack in triviaPacks where pack.isUnlocked {

            // First, try inside the TriviaPacks subdirectory
            let urlInFolder = Bundle.main.url(
                forResource: pack.fileName,
                withExtension: "json",
                subdirectory: "TriviaPacks"
            )

            // Fallback: try at the root of the bundle
            let url = urlInFolder ?? Bundle.main.url(
                forResource: pack.fileName,
                withExtension: "json"
            )

            guard let finalURL = url else {
                print("⚠️ Could not find \(pack.fileName).json in bundle (including TriviaPacks subfolder)")
                continue
            }

            do {
                let data = try Data(contentsOf: finalURL)
                let decoded = try JSONDecoder().decode([TriviaQuestion].self, from: data)
                combined.append(contentsOf: decoded)
            } catch {
                print("⚠️ Failed to decode \(pack.fileName).json: \(error)")
            }
        }

        // Optional: still support old single trivia.json if you keep it
        if let url = Bundle.main.url(forResource: "trivia", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([TriviaQuestion].self, from: data) {
            combined.append(contentsOf: decoded)
        }

        triviaBank = combined.shuffled()
        endlessCursorIndex = 0

        if triviaBank.isEmpty {
            print("⚠️ Trivia bank is empty – no packs decoded")
        }
    }

    func ensureTodayTrivia() {
        // Always make sure the bank is ready for endless mode
        loadTriviaIfNeeded()

        let today = DailyClock.currentDayKey()

        // 1) Primary source: today's quote's embedded trivia (quotes.json)
        let quoteTrivia = todayQuote.trivia
        let trimmedQuestion = quoteTrivia.question
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let hasValidQuoteTrivia =
            !trimmedQuestion.isEmpty &&
            !quoteTrivia.choices.isEmpty &&
            quoteTrivia.correctIndex >= 0 &&
            quoteTrivia.correctIndex < quoteTrivia.choices.count

        if hasValidQuoteTrivia {
            // Stable ID based on the quote's date so we can reuse it if needed
            let id = "quote-\(todayQuote.date)"

            let fromQuote = TriviaQuestion(
                id: id,
                movieTitle: todayQuote.movie,
                year: todayQuote.year,
                genre: "Daily",
                difficulty: "mixed",
                question: quoteTrivia.question,
                options: quoteTrivia.choices,
                correctIndex: quoteTrivia.correctIndex,
                extraInfo: nil
            )

            todayTrivia = fromQuote
            defaults.set(today, forKey: kTriviaLastDate)
            defaults.set(id, forKey: kTriviaLastQuestionID)
            return
        }

        // 2) Fallback: reuse trivia-pack-based question if already chosen for today
        let storedDate = defaults.string(forKey: kTriviaLastDate)
        let storedID = defaults.string(forKey: kTriviaLastQuestionID)

        if storedDate == today,
           let id = storedID,
           let existing = triviaBank.first(where: { $0.id == id }) {
            todayTrivia = existing
            return
        }

        // 3) Fallback: pick a fresh random question from the combined trivia bank
        guard !triviaBank.isEmpty,
              let new = triviaBank.randomElement() else {
            return
        }

        todayTrivia = new
        defaults.set(today, forKey: kTriviaLastDate)
        defaults.set(new.id, forKey: kTriviaLastQuestionID)
    }

    // MARK: - Register Answer

    func registerAnswer(correct: Bool) {
        let today = DailyClock.currentDayKey()

        guard (defaults.string(forKey: kLastAnsweredDay) ?? "") != today else {
            return
        }

        // Daily streak
        let lastPlay = defaults.string(forKey: kLastPlayDay) ?? ""

        if lastPlay == DailyClock.dayKey(offsetDays: -1) {
            dailyStreak += 1
        } else if lastPlay == today {
            // no-op
        } else {
            dailyStreak = 1
        }

        defaults.set(today, forKey: kLastPlayDay)
        defaults.set(dailyStreak, forKey: kDailyStreak)

        // Correct streak
        if correct {
            let lastCorrect = defaults.string(forKey: kLastCorrectDay) ?? ""

            if lastCorrect == DailyClock.dayKey(offsetDays: -1) {
                correctStreak += 1
            } else if lastCorrect == today {
                // no-op
            } else {
                correctStreak = 1
            }

            defaults.set(today, forKey: kLastCorrectDay)

        } else {
            correctStreak = 0
            defaults.set(today, forKey: kLastCorrectDay)
        }

        defaults.set(correctStreak, forKey: kCorrectStreak)

        // New record
        if correct && correctStreak > bestCorrectStreak {
            showNewRecordToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
                self?.showNewRecordToast = false
            }
        }

        if correctStreak > bestCorrectStreak {
            bestCorrectStreak = correctStreak
            defaults.set(bestCorrectStreak, forKey: kBestCorrectStreak)
        }

        // Lock day
        defaults.set(today, forKey: kLastAnsweredDay)
        quizCompletedToday = true
        defaults.set(correct, forKey: kLastResultWasCorrect)
        lastResultWasCorrect = correct
        currentStreak = correctStreak

        #if DEBUG
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - Fallback quote

    private func fallbackQuote() -> Quote {
        Quote(
            date: dayKey,
            text: "Hope is a good thing, maybe the best of things.",
            movie: "The Shawshank Redemption",
            year: 1994,
            trivia: Trivia(
                question: "Which real prison was used for Shawshank’s exterior/interiors?",
                choices: [
                    "Ohio State Reformatory",
                    "Joliet Correctional Center",
                    "Eastern State Penitentiary",
                    "Sing Sing Correctional Facility"
                ],
                correctIndex: 0
            )
        )
    }

    // MARK: - Reminder refresh

    private func refreshReminderIfNeededForToday() {
        let d = UserDefaults.standard
        let h = d.integer(forKey: Prefs.reminderHourKey)
        let m = d.integer(forKey: Prefs.reminderMinuteKey)
        let raw = d.integer(forKey: Prefs.reminderModeKey)

        guard (h > 0 || m > 0),
              let mode = ReminderContentMode(rawValue: raw) else { return }

        NotificationHelper.isReminderScheduled { isOn in
            guard isOn else { return }

            let needsQuote = (mode == .triviaAndQuote || mode == .quoteOnly)

            let quoteText: String? = needsQuote ? self.todayQuote.text : nil
            let movieTitle: String? = needsQuote ? self.todayQuote.movie : nil

            NotificationHelper.refreshDailyReminderBody(
                hour: h,
                minute: m,
                mode: mode,
                todaysQuote: quoteText,
                todaysMovie: movieTitle
            ) { _ in }
        }
    }

    func clearNewRecordToast() {
        if showNewRecordToast {
            showNewRecordToast = false
        }
    }

    // MARK: - DEBUG

    #if DEBUG
    func debugResetAll() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }

        let groupID = "group.com.chrisolah.FilmFuel"
        if let suite = UserDefaults(suiteName: groupID) {
            suite.removePersistentDomain(forName: groupID)
            suite.synchronize()
        }

        currentStreak = 0
        dailyStreak = 0
        correctStreak = 0
        bestCorrectStreak = 0

        quizCompletedToday = false
        showNewRecordToast = false
        lastResultWasCorrect = nil

        let today = DailyClock.currentDayKey()

        dayKey = today
        todayQuote = repo.quote(forDayKey: today)
            ?? repo.rotatingQuote(forDayKey: today)
            ?? fallbackQuote()
        allQuotes = repo.quotes

        UserDefaults(suiteName: groupID)?
            .removeObject(forKey: "FilmFuel.today.entry")

        WidgetCenter.shared.reloadAllTimelines()
    }

    func debugClearTodayCompletion() {
        let d = UserDefaults.standard

        d.removeObject(forKey: kLastAnsweredDay)
        d.removeObject(forKey: kLastResultWasCorrect)

        quizCompletedToday = false
        lastResultWasCorrect = nil
        showNewRecordToast = false

        WidgetCenter.shared.reloadAllTimelines()
    }

    func debugSetYesterdayCompleted() {
        let y = DailyClock.dayKey(offsetDays: -1)

        defaults.set(y, forKey: kLastAnsweredDay)
        defaults.set(y, forKey: kLastPlayDay)
        defaults.set(y, forKey: kLastCorrectDay)

        if dailyStreak == 0 {
            dailyStreak = 1
            defaults.set(1, forKey: kDailyStreak)
        }

        if correctStreak == 0 {
            correctStreak = 1
            defaults.set(1, forKey: kCorrectStreak)
        }

        if bestCorrectStreak == 0 {
            bestCorrectStreak = 1
            defaults.set(1, forKey: kBestCorrectStreak)
        }

        currentStreak = correctStreak
        quizCompletedToday = false
        showNewRecordToast = false
        lastResultWasCorrect = nil

        WidgetCenter.shared.reloadAllTimelines()
    }
    #endif
}
