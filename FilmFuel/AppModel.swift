//
//  AppModel.swift
//  FilmFuel
//
//  Enhanced with gamification integration, XP hooks, and engagement tracking
//

import Foundation
import Combine
import UserNotifications
#if DEBUG
import WidgetKit
#endif

// MARK: - Trivia Model

struct TriviaQuestion: Identifiable, Codable, Hashable {
    let id: String
    let movieTitle: String
    let year: Int
    let genre: String?
    let difficulty: String  // "easy", "normal", "challenging"
    let question: String
    let options: [String]
    let correctIndex: Int
    let extraInfo: String?
    
    var difficultyXPMultiplier: Double {
        switch difficulty.lowercased() {
        case "easy": return 1.0
        case "normal": return 1.5
        case "challenging", "hard": return 2.0
        default: return 1.0
        }
    }
}

struct TriviaPack: Identifiable {
    let id: String
    let displayName: String
    let fileName: String
    let isPremium: Bool
    var isUnlocked: Bool
    let icon: String
    let questionCount: Int?
    
    init(id: String, displayName: String, fileName: String, isPremium: Bool, isUnlocked: Bool, icon: String = "film.fill", questionCount: Int? = nil) {
        self.id = id
        self.displayName = displayName
        self.fileName = fileName
        self.isPremium = isPremium
        self.isUnlocked = isUnlocked
        self.icon = icon
        self.questionCount = questionCount
    }
}

// MARK: - Reminder Preferences

enum Prefs {
    static let reminderHourKey = "ff.reminder.hour"
    static let reminderMinuteKey = "ff.reminder.minute"
    static let reminderModeKey = "ff.reminder.mode"
}

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

// MARK: - Notification Helper

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
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: reminderId, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderId])
        UNUserNotificationCenter.current().add(request) { err in
            completion(err == nil)
        }
    }
    
    static func scheduleDailyReminder(
        hour: Int,
        minute: Int,
        mode: ReminderContentMode,
        quotePreview: String?,
        completion: @escaping (Bool) -> Void
    ) {
        scheduleDailyReminder(hour: hour, minute: minute, mode: mode, quote: quotePreview, movie: nil, completion: completion)
    }
    
    static func refreshDailyReminderBody(
        hour: Int,
        minute: Int,
        mode: ReminderContentMode,
        todaysQuote: String?,
        todaysMovie: String?,
        completion: @escaping (Bool) -> Void
    ) {
        scheduleDailyReminder(hour: hour, minute: minute, mode: mode, quote: todaysQuote, movie: todaysMovie, completion: completion)
    }
    
    static func refreshDailyReminderBody(
        hour: Int,
        minute: Int,
        mode: ReminderContentMode,
        todaysQuote: String?,
        completion: @escaping (Bool) -> Void
    ) {
        refreshDailyReminderBody(hour: hour, minute: minute, mode: mode, todaysQuote: todaysQuote, todaysMovie: nil, completion: completion)
    }
    
    static func cancelDailyReminder(_ completion: @escaping () -> Void) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderId])
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
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
            let request = UNNotificationRequest(identifier: "ff.test.\(UUID().uuidString)", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }
    
    private static func makeContent(mode: ReminderContentMode, quote: String?, movie: String?) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        
        switch mode {
        case .triviaOnly:
            c.title = "🎬 FilmFuel Quiz"
            c.body = "Your daily movie quiz is ready. Keep your streak alive!"
            
        case .triviaAndQuote:
            c.title = "🎬 FilmFuel"
            if let q = quote, !q.isEmpty, let m = movie, !m.isEmpty {
                c.body = "\"\(q)\" — \(m)"
            } else if let q = quote, !q.isEmpty {
                c.body = "\"\(q)\""
            } else {
                c.body = "Your quote & quiz are ready."
            }
            
        case .quoteOnly:
            c.title = "🎬 FilmFuel Quote"
            if let q = quote, !q.isEmpty, let m = movie, !m.isEmpty {
                c.body = "\"\(q)\" — \(m)"
            } else if let q = quote, !q.isEmpty {
                c.body = "Today's quote: \"\(q)\""
            } else {
                c.body = "Today's quote is ready."
            }
        }
        
        c.sound = .default
        return c
    }
}

// MARK: - App Model

final class AppModel: ObservableObject {
    
    // MARK: - Keys
    
    private let kDailyStreak = "ff.dailyStreak"
    private let kCorrectStreak = "ff.correctStreak"
    private let kBestCorrectStreak = "ff.bestCorrectStreak"
    private let kLastPlayDay = "ff.lastPlayDayKey"
    private let kLastCorrectDay = "ff.lastCorrectDayKey"
    private let kLastAnsweredDay = "ff.lastAnsweredDayKey"
    private let kLastResultWasCorrect = "ff.lastResultWasCorrect"
    private let kTriviaLastDate = "ff.trivia.lastDate"
    private let kTriviaLastQuestionID = "ff.trivia.lastQuestionID"
    
    // Legacy keys for migration
    private let kStreak = "ff.currentStreak"
    private let kLastCompletedDay = "ff.lastCompletedDayKey"
    private let kLastSeenDay = "ff.lastSeenDayKey"
    
    private var defaults: UserDefaults { .standard }
    
    // MARK: - Published State
    
    // Streaks
    @Published var currentStreak: Int = 0
    @Published var dailyStreak: Int = 0
    @Published var correctStreak: Int = 0
    @Published var bestCorrectStreak: Int = 0
    
    // Daily state
    @Published var quizCompletedToday: Bool = false
    @Published var dayKey: String = DailyClock.currentDayKey()
    @Published var showNewRecordToast: Bool = false
    @Published var lastResultWasCorrect: Bool? = nil
    
    // Quotes
    @Published var todayQuote: Quote = Quote(
        date: DailyClock.currentDayKey(),
        text: "Loading…",
        movie: "",
        year: 0,
        trivia: Trivia(question: "", choices: [], correctIndex: 0)
    )
    @Published var allQuotes: [Quote] = []
    
    // Trivia
    @Published var triviaBank: [TriviaQuestion] = []
    @Published var todayTrivia: TriviaQuestion?
    @Published private var endlessCursorIndex: Int = 0
    
    // Endless mode tracking
    @Published var currentEndlessRound: Int = 0
    @Published var currentEndlessCorrect: Int = 0
    @Published var bestEndlessRound: Int = 0
    
    // Gamification UI triggers
    @Published var showXPGainAnimation: Bool = false
    @Published var lastXPGain: Int = 0
    @Published var showAchievementUnlocked: Bool = false
    @Published var lastUnlockedAchievement: String?
    @Published var showLevelUpCelebration: Bool = false
    @Published var newLevelReached: Int?
    
    // MARK: - Trivia Packs
    
    private(set) var triviaPacks: [TriviaPack] = [
        TriviaPack(id: "classics", displayName: "Classics", fileName: "trivia_classics", isPremium: false, isUnlocked: true, icon: "film.fill"),
        TriviaPack(id: "scifi", displayName: "Sci-Fi", fileName: "trivia_scifi", isPremium: false, isUnlocked: true, icon: "sparkles"),
        TriviaPack(id: "pixar", displayName: "Pixar", fileName: "trivia_pixar", isPremium: false, isUnlocked: true, icon: "paintpalette.fill"),
        TriviaPack(id: "nineties", displayName: "90s", fileName: "trivia_90s", isPremium: false, isUnlocked: true, icon: "clock.fill"),
        TriviaPack(id: "twoThousands", displayName: "2000s", fileName: "trivia_2000s", isPremium: false, isUnlocked: true, icon: "clock.fill"),
        TriviaPack(id: "modern", displayName: "Modern", fileName: "trivia_modern", isPremium: false, isUnlocked: true, icon: "sparkles.tv.fill"),
        TriviaPack(id: "horror", displayName: "Horror", fileName: "trivia_horror", isPremium: false, isUnlocked: true, icon: "moon.fill"),
        TriviaPack(id: "nolan", displayName: "Christopher Nolan", fileName: "trivia_nolan", isPremium: true, isUnlocked: true, icon: "brain.fill"),
        TriviaPack(id: "tarantino", displayName: "Tarantino", fileName: "trivia_tarantino", isPremium: true, isUnlocked: true, icon: "drop.fill"),
        TriviaPack(id: "avengers", displayName: "Avengers", fileName: "trivia_avengers", isPremium: true, isUnlocked: true, icon: "shield.fill"),
    ]
    
    // MARK: - Private
    
    private let repo = QuotesRepository(jsonFileName: "quotes")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init() {
        let today = DailyClock.currentDayKey()
        dayKey = today
        
        // Load streaks
        dailyStreak = max(0, defaults.integer(forKey: kDailyStreak))
        correctStreak = max(0, defaults.integer(forKey: kCorrectStreak))
        bestCorrectStreak = max(0, defaults.integer(forKey: kBestCorrectStreak))
        bestEndlessRound = defaults.integer(forKey: "ff.bestEndlessRound")
        
        // Migration from old system
        migrateFromOldSystem()
        
        currentStreak = correctStreak
        
        // Check today's completion
        let lastAnswered = defaults.string(forKey: kLastAnsweredDay) ?? defaults.string(forKey: kLastCompletedDay) ?? ""
        quizCompletedToday = (lastAnswered == today)
        lastResultWasCorrect = quizCompletedToday ? (defaults.object(forKey: kLastResultWasCorrect) as? Bool) : nil
        
        // Load quote
        todayQuote = repo.quote(forDayKey: today) ?? repo.rotatingQuote(forDayKey: today) ?? fallbackQuote()
        allQuotes = repo.quotes
        
        defaults.set(today, forKey: kLastSeenDay)
        
        // Setup
        refreshReminderIfNeededForToday()
        loadTriviaIfNeeded()
        ensureTodayTrivia()
        setupNotificationObservers()
    }
    
    // MARK: - Migration
    
    private func migrateFromOldSystem() {
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
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Listen for XP gains
        NotificationCenter.default.publisher(for: StatsManager.xpGained)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let amount = notification.userInfo?["amount"] as? Int {
                    self?.lastXPGain = amount
                    self?.showXPGainAnimation = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self?.showXPGainAnimation = false
                    }
                }
            }
            .store(in: &cancellables)
        
        // Listen for achievements
        NotificationCenter.default.publisher(for: StatsManager.achievementUnlocked)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let id = notification.userInfo?["id"] as? String {
                    self?.lastUnlockedAchievement = id
                    self?.showAchievementUnlocked = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self?.showAchievementUnlocked = false
                    }
                }
            }
            .store(in: &cancellables)
        
        // Listen for level ups
        NotificationCenter.default.publisher(for: StatsManager.levelUp)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let newLevel = notification.userInfo?["newLevel"] as? Int {
                    self?.newLevelReached = newLevel
                    self?.showLevelUpCelebration = true
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Daily Refresh
    
    func refreshDailyStateIfNeeded() {
        let newKey = DailyClock.currentDayKey()
        guard newKey != dayKey else { return }
        
        dayKey = newKey
        todayQuote = repo.quote(forDayKey: newKey) ?? repo.rotatingQuote(forDayKey: newKey) ?? fallbackQuote()
        allQuotes = repo.quotes
        
        let lastAnswered = defaults.string(forKey: kLastAnsweredDay) ?? defaults.string(forKey: kLastCompletedDay) ?? ""
        quizCompletedToday = (lastAnswered == newKey)
        lastResultWasCorrect = quizCompletedToday ? (defaults.object(forKey: kLastResultWasCorrect) as? Bool) : nil
        
        // Reset endless mode for new day
        currentEndlessRound = 0
        currentEndlessCorrect = 0
        
        refreshReminderIfNeededForToday()
        ensureTodayTrivia()
    }
    
    // MARK: - Endless Trivia
    
    func nextEndlessTriviaQuestion() -> TriviaQuestion? {
        loadTriviaIfNeeded()
        guard !triviaBank.isEmpty else { return nil }
        
        if endlessCursorIndex >= triviaBank.count {
            triviaBank.shuffle()
            endlessCursorIndex = 0
        }
        
        let q = triviaBank[endlessCursorIndex]
        endlessCursorIndex += 1
        currentEndlessRound += 1
        
        return q
    }
    
    func registerEndlessAnswer(correct: Bool, question: TriviaQuestion) {
        // Track in StatsManager
        StatsManager.shared.trackEndlessTriviaAnswer(correct: correct)
        
        if correct {
            currentEndlessCorrect += 1
            
            // XP based on difficulty
            let baseXP = 5
            let xp = Int(Double(baseXP) * question.difficultyXPMultiplier)
            StatsManager.shared.addXP(xp, reason: "Endless trivia correct")
        }
        
        // Track genre explored
        if let genre = question.genre {
            // Map genre string to ID if needed, or just track the string
            StatsManager.shared.trackMoodExplored(genre)
        }
    }
    
    func endEndlessSession() {
        // Track session completion
        StatsManager.shared.trackEndlessTriviaSessionCompleted()
        
        // Check for perfect round
        if currentEndlessCorrect == currentEndlessRound && currentEndlessRound >= 5 {
            StatsManager.shared.trackPerfectRound()
        }
        
        // Update best
        if currentEndlessRound > bestEndlessRound {
            bestEndlessRound = currentEndlessRound
            defaults.set(bestEndlessRound, forKey: "ff.bestEndlessRound")
        }
        
        // Bonus XP for long sessions
        if currentEndlessRound >= 10 {
            StatsManager.shared.addXP(15, reason: "Extended endless session")
        } else if currentEndlessRound >= 5 {
            StatsManager.shared.addXP(5, reason: "Endless session")
        }
        
        // Reset
        currentEndlessRound = 0
        currentEndlessCorrect = 0
    }
    
    // MARK: - Trivia Loading
    
    func loadTriviaIfNeeded() {
        if !triviaBank.isEmpty { return }
        
        var combined: [TriviaQuestion] = []
        
        for pack in triviaPacks where pack.isUnlocked {
            let urlInFolder = Bundle.main.url(forResource: pack.fileName, withExtension: "json", subdirectory: "TriviaPacks")
            let url = urlInFolder ?? Bundle.main.url(forResource: pack.fileName, withExtension: "json")
            
            guard let finalURL = url else {
                print("⚠️ Could not find \(pack.fileName).json")
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
        
        // Legacy single trivia.json support
        if let url = Bundle.main.url(forResource: "trivia", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([TriviaQuestion].self, from: data) {
            combined.append(contentsOf: decoded)
        }
        
        triviaBank = combined.shuffled()
        endlessCursorIndex = 0
    }
    
    func ensureTodayTrivia() {
        loadTriviaIfNeeded()
        
        let today = DailyClock.currentDayKey()
        
        // Primary: today's quote's embedded trivia
        let quoteTrivia = todayQuote.trivia
        let trimmedQuestion = quoteTrivia.question.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let hasValidQuoteTrivia = !trimmedQuestion.isEmpty &&
            !quoteTrivia.choices.isEmpty &&
            quoteTrivia.correctIndex >= 0 &&
            quoteTrivia.correctIndex < quoteTrivia.choices.count
        
        if hasValidQuoteTrivia {
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
        
        // Fallback: reuse if already chosen today
        let storedDate = defaults.string(forKey: kTriviaLastDate)
        let storedID = defaults.string(forKey: kTriviaLastQuestionID)
        
        if storedDate == today, let id = storedID, let existing = triviaBank.first(where: { $0.id == id }) {
            todayTrivia = existing
            return
        }
        
        // Fallback: pick random
        guard !triviaBank.isEmpty, let new = triviaBank.randomElement() else { return }
        
        todayTrivia = new
        defaults.set(today, forKey: kTriviaLastDate)
        defaults.set(new.id, forKey: kTriviaLastQuestionID)
    }
    
    // MARK: - Register Daily Answer
    
    func registerAnswer(correct: Bool) {
        let today = DailyClock.currentDayKey()
        
        guard (defaults.string(forKey: kLastAnsweredDay) ?? "") != today else { return }
        
        // Track in StatsManager
        StatsManager.shared.trackTriviaQuestionAnswered(correct: correct)
        StatsManager.shared.trackDailyTriviaSessionCompleted()
        
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
            
            // Award XP for daily quiz
            let baseXP = 10
            let streakBonus = min(correctStreak, 10) // Up to 10 bonus XP for streak
            StatsManager.shared.addXP(baseXP + streakBonus, reason: "Daily quiz correct")
            
        } else {
            correctStreak = 0
            defaults.set(today, forKey: kLastCorrectDay)
            
            // Small XP for attempting
            StatsManager.shared.addXP(2, reason: "Daily quiz attempted")
        }
        
        defaults.set(correctStreak, forKey: kCorrectStreak)
        
        // New record
        if correct && correctStreak > bestCorrectStreak {
            showNewRecordToast = true
            StatsManager.shared.addXP(25, reason: "New streak record!")
            
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
    
    // MARK: - Helpers
    
    private func fallbackQuote() -> Quote {
        Quote(
            date: dayKey,
            text: "Hope is a good thing, maybe the best of things.",
            movie: "The Shawshank Redemption",
            year: 1994,
            trivia: Trivia(
                question: "Which real prison was used for Shawshank's exterior/interiors?",
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
    
    private func refreshReminderIfNeededForToday() {
        let d = UserDefaults.standard
        let h = d.integer(forKey: Prefs.reminderHourKey)
        let m = d.integer(forKey: Prefs.reminderMinuteKey)
        let raw = d.integer(forKey: Prefs.reminderModeKey)
        
        guard (h > 0 || m > 0), let mode = ReminderContentMode(rawValue: raw) else { return }
        
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
    
    func dismissLevelUpCelebration() {
        showLevelUpCelebration = false
        newLevelReached = nil
    }
    
    // MARK: - Gamification Accessors
    
    var userXP: Int {
        StatsManager.shared.totalXP
    }
    
    var userLevel: Int {
        StatsManager.shared.userLevel
    }
    
    var userLevelTitle: String {
        StatsManager.shared.userLevelTitle
    }
    
    var triviaAccuracy: Int {
        StatsManager.shared.triviaAccuracy
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
        currentEndlessRound = 0
        currentEndlessCorrect = 0
        bestEndlessRound = 0
        
        let today = DailyClock.currentDayKey()
        dayKey = today
        todayQuote = repo.quote(forDayKey: today) ?? repo.rotatingQuote(forDayKey: today) ?? fallbackQuote()
        allQuotes = repo.quotes
        
        UserDefaults(suiteName: groupID)?.removeObject(forKey: "FilmFuel.today.entry")
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func debugClearTodayCompletion() {
        defaults.removeObject(forKey: kLastAnsweredDay)
        defaults.removeObject(forKey: kLastResultWasCorrect)
        
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
