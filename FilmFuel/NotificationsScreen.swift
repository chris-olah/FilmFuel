import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Reminder config

enum FFReminderMode: String, CaseIterable, Identifiable, Codable {
    case off = "Off"
    case quoteOnly = "Quote Only"
    case triviaOnly = "Trivia Only"
    case quoteAndTrivia = "Quote + Trivia"

    var id: String { rawValue }
}

struct FFReminderSettings: Codable, Equatable {
    var mode: FFReminderMode = .quoteOnly

    // Quote time (12h UI + AM/PM)
    var quoteHour: Int = 9   // 1...12
    var quoteMinute: Int = 0 // 0...59
    var quoteIsPM: Bool = false

    // Trivia time (12h UI + AM/PM)
    var triviaHour: Int = 6
    var triviaMinute: Int = 0
    var triviaIsPM: Bool = true
}

// MARK: - Lightweight models

struct FFQuote {
    let text: String
    let movie: String
}

struct FFTrivia {
    let question: String
    let answer: String
}

// MARK: - Local IDs & constants used only in this file

/// Local notification identifiers (unique within app)
private let ffQuoteNotificationID = "FF.daily.quote"
private let ffTriviaNotificationID = "FF.daily.trivia"

/// Match the category/action IDs defined in AppRoute’s FFNotificationManager.configure()
private let ffQuizCategoryID = "QUIZ_REMINDER"
private let ffQuoteCategoryID = "QUOTE_REMINDER"
private let ffActionQuizID = "OPEN_QUIZ"
private let ffActionShareID = "SHARE_QUOTE"

// MARK: - Extend the existing FFNotificationManager for scheduling

extension FFNotificationManager {

    /// Convert 12h + AM/PM -> 24h
    static func hour24(from12h h: Int, isPM: Bool) -> Int {
        // 12 AM -> 0, 12 PM -> 12
        if h == 12 {
            return isPM ? 12 : 0
        }
        return isPM ? (h + 12) : h
    }

    /// Reschedule quote/trivia based on current settings
    func reschedule(
        settings: FFReminderSettings,
        quote: FFQuote?,
        trivia: FFTrivia?
    ) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [ffQuoteNotificationID, ffTriviaNotificationID])

        switch settings.mode {
        case .off:
            return

        case .quoteOnly:
            if let q = quote {
                scheduleQuote(
                    q,
                    hour24: Self.hour24(from12h: settings.quoteHour, isPM: settings.quoteIsPM),
                    minute: settings.quoteMinute
                )
            }

        case .triviaOnly:
            if let t = trivia {
                scheduleTrivia(
                    t,
                    hour24: Self.hour24(from12h: settings.triviaHour, isPM: settings.triviaIsPM),
                    minute: settings.triviaMinute
                )
            }

        case .quoteAndTrivia:
            if let q = quote {
                scheduleQuote(
                    q,
                    hour24: Self.hour24(from12h: settings.quoteHour, isPM: settings.quoteIsPM),
                    minute: settings.quoteMinute
                )
            }
            if let t = trivia {
                scheduleTrivia(
                    t,
                    hour24: Self.hour24(from12h: settings.triviaHour, isPM: settings.triviaIsPM),
                    minute: settings.triviaMinute
                )
            }
        }
    }

    // MARK: - Private helpers

    private func scheduleQuote(_ quote: FFQuote, hour24: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🎬 Your Daily FilmFuel"
        content.body = "“\(quote.text)” — \(quote.movie)"
        content.sound = .default
        // Use the quote category defined in AppRoute.configure()
        content.categoryIdentifier = ffQuoteCategoryID
        // Hint for default banner-tap routing
        content.userInfo = ["route": "share-quote"]

        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let trigger = dailyTrigger(hour: hour24, minute: minute)

        let req = UNNotificationRequest(
            identifier: ffQuoteNotificationID,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(req) { err in
            if let err {
                print("❌ Quote schedule error: \(err)")
            } else {
                print("✅ Quote @ \(hour24):\(String(format: "%02d", minute))")
            }
        }
    }

    private func scheduleTrivia(_ trivia: FFTrivia, hour24: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🎥 FilmFuel Trivia"
        content.body = trivia.question
        content.sound = .default
        // Use the quiz category defined in AppRoute.configure()
        content.categoryIdentifier = ffQuizCategoryID
        content.userInfo = ["route": "quiz"]

        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let trigger = dailyTrigger(hour: hour24, minute: minute)

        let req = UNNotificationRequest(
            identifier: ffTriviaNotificationID,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(req) { err in
            if let err {
                print("❌ Trivia schedule error: \(err)")
            } else {
                print("✅ Trivia @ \(hour24):\(String(format: "%02d", minute))")
            }
        }
    }

    private func dailyTrigger(hour: Int, minute: Int) -> UNCalendarNotificationTrigger {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
    }
}

// MARK: - Dedicated notification center delegate

/// Separate delegate object so we don’t need FFNotificationManager to inherit from NSObject.
final class FFNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {

    static let shared = FFNotificationCenterDelegate()

    private override init() {
        super.init()
    }

    // Foreground presentation
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    // Handle action buttons & banner taps
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let route = (info["route"] as? String ?? "").lowercased()

        switch response.actionIdentifier {
        case ffActionQuizID, ffActionShareID:
            // Use the existing handler defined in AppRoute.swift
            FFNotificationManager.shared.handleNotificationAction(response.actionIdentifier)

        default:
            // Tapped the banner / default action -> infer from userInfo["route"]
            if route == "quiz" {
                FFNotificationManager.shared.handleNotificationAction(ffActionQuizID)
            } else if route == "share-quote" {
                FFNotificationManager.shared.handleNotificationAction(ffActionShareID)
            }
        }

        completionHandler()
    }
}

// MARK: - Notifications Screen (UI)

struct NotificationsScreen: View {

    @EnvironmentObject private var appModel: AppModel

    @State private var settings: FFReminderSettings = .init()

    // Permission status UI state
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    // Derived content
    private var todayQuoteFF: FFQuote {
        FFQuote(text: appModel.todayQuote.text, movie: appModel.todayQuote.movie)
    }

    private var todayTriviaFF: FFTrivia {
        let t = appModel.todayQuote.trivia
        let answer = (t.correctIndex >= 0 && t.correctIndex < t.choices.count)
            ? t.choices[t.correctIndex]
            : ""
        return FFTrivia(question: t.question, answer: answer)
    }

    // Date bindings for compact pickers (bridge hour/minute/AMPM <-> Date)
    private var quoteTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                Self.makeDate(
                    h: settings.quoteHour,
                    m: settings.quoteMinute,
                    isPM: settings.quoteIsPM
                )
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                let h24 = comps.hour ?? 9
                let (h12, isPM) = Self.h12isPM(from24: h24)

                settings.quoteHour = h12
                settings.quoteMinute = comps.minute ?? 0
                settings.quoteIsPM = isPM

                persistAndReschedule()
            }
        )
    }

    private var triviaTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                Self.makeDate(
                    h: settings.triviaHour,
                    m: settings.triviaMinute,
                    isPM: settings.triviaIsPM
                )
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                let h24 = comps.hour ?? 18
                let (h12, isPM) = Self.h12isPM(from24: h24)

                settings.triviaHour = h12
                settings.triviaMinute = comps.minute ?? 0
                settings.triviaIsPM = isPM

                persistAndReschedule()
            }
        )
    }

    var body: some View {
        Form {
            // Permission row
            Section {
                HStack {
                    Image(systemName: iconForStatus(authStatus))
                        .foregroundStyle(colorForStatus(authStatus))

                    Text(labelForStatus(authStatus))
                        .foregroundStyle(.primary)

                    Spacer()

                    if authStatus == .denied {
                        Button("Open Settings") {
                            openSystemSettings()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .accessibilityElement(children: .combine)
            } header: {
                Text("Notification Permission")
            } footer: {
                if authStatus != .authorized {
                    Text("Turn notifications on so your daily quote and trivia arrive on time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // Mode picker
            Section {
                Picker("Daily Reminders", selection: $settings.mode) {
                    ForEach(FFReminderMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.mode) {
                    persistAndReschedule()
                }
                Text(modeHelpText(settings.mode))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if settings.mode == .quoteOnly || settings.mode == .quoteAndTrivia {
                Section(header: Text("Quote")) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "quote.bubble.fill")
                            .foregroundStyle(.blue)

                        Text("“\(todayQuoteFF.text)” — \(todayQuoteFF.movie)")
                            .font(.callout)
                            .lineLimit(3)
                    }

                    DatePicker(
                        "Time",
                        selection: quoteTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)

                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(.secondary)

                        Text("Next reminder: \(nextFireDateText(h12: settings.quoteHour, m: settings.quoteMinute, isPM: settings.quoteIsPM))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if settings.mode == .triviaOnly || settings.mode == .quoteAndTrivia {
                Section(header: Text("Trivia")) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "gamecontroller.fill")
                            .foregroundStyle(.purple)

                        Text(todayTriviaFF.question)
                            .font(.callout)
                            .lineLimit(3)
                    }

                    DatePicker(
                        "Time",
                        selection: triviaTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)

                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(.secondary)

                        Text("Next reminder: \(nextFireDateText(h12: settings.triviaHour, m: settings.triviaMinute, isPM: settings.triviaIsPM))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .onAppear {
            // 1) Ensure categories from AppRoute are registered
            FFNotificationManager.shared.configure()

            // 2) Set delegate + request auth here for UI purposes
            let center = UNUserNotificationCenter.current()
            center.delegate = FFNotificationCenterDelegate.shared

            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, err in
                if let err {
                    print("🔔 Auth error: \(err)")
                }
                print("🔔 Notifications \(granted ? "granted" : "denied")")
                refreshAuthStatus()
            }

            if let stored = appModel.reminderSettingsBridge() {
                settings = stored
            } else if let migrated = migrateFromLegacyPrefs() {
                settings = migrated
                persist() // write into App Group / shared storage
            }

            // Ensure current UI state is scheduled
            persistAndReschedule()
            refreshAuthStatus()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.willEnterForegroundNotification
            )
        ) { _ in
            refreshAuthStatus()
        }
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - Permission helpers

    private func refreshAuthStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async {
                self.authStatus = s.authorizationStatus
            }
        }
    }

    private func iconForStatus(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return "bell.badge.fill"
        case .denied:
            return "bell.slash.fill"
        case .notDetermined:
            return "bell"
        @unknown default:
            return "bell"
        }
    }

    private func colorForStatus(_ status: UNAuthorizationStatus) -> Color {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }

    private func labelForStatus(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return "Notifications: On"
        case .denied:
            return "Notifications: Off"
        case .notDetermined:
            return "Notifications: Not Determined"
        @unknown default:
            return "Notifications"
        }
    }

    private func openSystemSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        #endif
    }

    // MARK: - Persistence + Scheduling

    private func persist() {
        appModel.updateReminderSettingsBridge(settings)
    }

    private func persistAndReschedule() {
        persist()
        FFNotificationManager.shared.reschedule(
            settings: settings,
            quote: todayQuoteFF,
            trivia: todayTriviaFF
        )
    }

    // MARK: - Helpers

    private func nextFireDateText(h12: Int, m: Int, isPM: Bool) -> String {
        let hour24 = FFNotificationManager.hour24(from12h: h12, isPM: isPM)

        var comps = DateComponents()
        comps.hour = hour24
        comps.minute = m

        let cal = Calendar.current
        let now = Date()

        let next = cal.nextDate(
            after: now,
            matching: comps,
            matchingPolicy: .nextTimePreservingSmallerComponents
        ) ?? now

        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: next)
    }

    private static func makeDate(h: Int, m: Int, isPM: Bool) -> Date {
        let hour24 = FFNotificationManager.hour24(from12h: h, isPM: isPM)

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour24
        comps.minute = m

        return Calendar.current.date(from: comps) ?? Date()
    }

    private static func h12isPM(from24 h24: Int) -> (Int, Bool) {
        if h24 == 0 {
            return (12, false) // 0 -> 12 AM
        }
        if h24 == 12 {
            return (12, true)  // 12 -> 12 PM
        }
        if h24 > 12 {
            return (h24 - 12, true)
        }
        return (h24, false)
    }

    private func modeHelpText(_ mode: FFReminderMode) -> String {
        switch mode {
        case .off:
            return "Reminders are disabled."
        case .quoteOnly:
            return "Sends a daily quote with the movie title."
        case .triviaOnly:
            return "Sends the daily trivia question."
        case .quoteAndTrivia:
            return "Sends both a quote and a trivia question at their times."
        }
    }

    // Optional: migrate once from legacy standard-UserDefaults keys (if present)
    private func migrateFromLegacyPrefs() -> FFReminderSettings? {
        // These keys/types come from your AppModel.swift
        let d = UserDefaults.standard
        let hour24 = d.integer(forKey: Prefs.reminderHourKey)
        let minute = d.integer(forKey: Prefs.reminderMinuteKey)
        let rawMode = d.integer(forKey: Prefs.reminderModeKey)

        guard (hour24 > 0 || minute > 0) else {
            return nil
        }

        var mode: FFReminderMode = .quoteOnly

        if let legacy = ReminderContentMode(rawValue: rawMode) {
            switch legacy {
            case .triviaOnly:
                mode = .triviaOnly
            case .triviaAndQuote:
                mode = .quoteAndTrivia
            case .quoteOnly:
                mode = .quoteOnly
            }
        }

        let (h12, isPM) = Self.h12isPM(from24: hour24)

        // Single legacy reminder -> map to quote by default
        return FFReminderSettings(
            mode: mode,
            quoteHour: h12,
            quoteMinute: minute,
            quoteIsPM: isPM,
            triviaHour: 6,
            triviaMinute: 0,
            triviaIsPM: true
        )
    }
}

// MARK: - Minimal AppModel bridges (App Group persistence)

extension AppModel {
    private var groupID: String { "group.com.chrisolah.FilmFuel" }
    private var settingsKey: String { "ff.reminder.settings" }

    func reminderSettingsBridge() -> FFReminderSettings? {
        guard let data = UserDefaults(suiteName: groupID)?.data(forKey: settingsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(FFReminderSettings.self, from: data)
    }

    func updateReminderSettingsBridge(_ settings: FFReminderSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults(suiteName: groupID)?.set(data, forKey: settingsKey)
    }
}
