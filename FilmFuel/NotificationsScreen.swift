//
//  NotificationsScreen.swift
//  FilmFuel
//

import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Reminder config (unchanged)

enum FFReminderMode: String, CaseIterable, Identifiable, Codable {
    case off = "Off"
    case quoteOnly = "Quote Only"
    case triviaOnly = "Trivia Only"
    case quoteAndTrivia = "Quote + Trivia"
    var id: String { rawValue }
}

struct FFReminderSettings: Codable, Equatable {
    var mode: FFReminderMode = .quoteOnly
    var quoteHour: Int = 9
    var quoteMinute: Int = 0
    var quoteIsPM: Bool = false
    var triviaHour: Int = 6
    var triviaMinute: Int = 0
    var triviaIsPM: Bool = true
}

// MARK: - Lightweight models (unchanged)

struct FFQuote {
    let text: String
    let movie: String
}

struct FFTrivia {
    let question: String
    let answer: String
}

// MARK: - Local IDs (unchanged)

private let ffQuoteNotificationID = "FF.daily.quote"
private let ffTriviaNotificationID = "FF.daily.trivia"
private let ffQuizCategoryID = "QUIZ_REMINDER"
private let ffQuoteCategoryID = "QUOTE_REMINDER"
private let ffActionQuizID = "OPEN_QUIZ"
private let ffActionShareID = "SHARE_QUOTE"

// MARK: - FFNotificationManager extension (unchanged)

extension FFNotificationManager {

    static func hour24(from12h h: Int, isPM: Bool) -> Int {
        if h == 12 { return isPM ? 12 : 0 }
        return isPM ? (h + 12) : h
    }

    func reschedule(settings: FFReminderSettings, quote: FFQuote?, trivia: FFTrivia?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [ffQuoteNotificationID, ffTriviaNotificationID])

        switch settings.mode {
        case .off: return
        case .quoteOnly:
            if let q = quote {
                scheduleQuote(q, hour24: Self.hour24(from12h: settings.quoteHour, isPM: settings.quoteIsPM), minute: settings.quoteMinute)
            }
        case .triviaOnly:
            if let t = trivia {
                scheduleTrivia(t, hour24: Self.hour24(from12h: settings.triviaHour, isPM: settings.triviaIsPM), minute: settings.triviaMinute)
            }
        case .quoteAndTrivia:
            if let q = quote {
                scheduleQuote(q, hour24: Self.hour24(from12h: settings.quoteHour, isPM: settings.quoteIsPM), minute: settings.quoteMinute)
            }
            if let t = trivia {
                scheduleTrivia(t, hour24: Self.hour24(from12h: settings.triviaHour, isPM: settings.triviaIsPM), minute: settings.triviaMinute)
            }
        }
    }

    private func scheduleQuote(_ quote: FFQuote, hour24: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🎬 Your Daily FilmFuel"
        content.body = "\u{201C}\(quote.text)\u{201D} \u{2014} \(quote.movie)"
        content.sound = .default
        content.categoryIdentifier = ffQuoteCategoryID
        content.userInfo = ["route": "share-quote"]
        if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }
        let req = UNNotificationRequest(identifier: ffQuoteNotificationID, content: content, trigger: dailyTrigger(hour: hour24, minute: minute))
        UNUserNotificationCenter.current().add(req) { err in
            if let err { print("❌ Quote schedule error: \(err)") }
            else { print("✅ Quote @ \(hour24):\(String(format: "%02d", minute))") }
        }
    }

    private func scheduleTrivia(_ trivia: FFTrivia, hour24: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🎥 FilmFuel Trivia"
        content.body = trivia.question
        content.sound = .default
        content.categoryIdentifier = ffQuizCategoryID
        content.userInfo = ["route": "quiz"]
        if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }
        let req = UNNotificationRequest(identifier: ffTriviaNotificationID, content: content, trigger: dailyTrigger(hour: hour24, minute: minute))
        UNUserNotificationCenter.current().add(req) { err in
            if let err { print("❌ Trivia schedule error: \(err)") }
            else { print("✅ Trivia @ \(hour24):\(String(format: "%02d", minute))") }
        }
    }

    private func dailyTrigger(hour: Int, minute: Int) -> UNCalendarNotificationTrigger {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
    }
}

// MARK: - Notification Center Delegate (unchanged)

final class FFNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = FFNotificationCenterDelegate()
    private override init() { super.init() }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let route = (info["route"] as? String ?? "").lowercased()
        switch response.actionIdentifier {
        case ffActionQuizID, ffActionShareID:
            FFNotificationManager.shared.handleNotificationAction(response.actionIdentifier)
        default:
            if route == "quiz" { FFNotificationManager.shared.handleNotificationAction(ffActionQuizID) }
            else if route == "share-quote" { FFNotificationManager.shared.handleNotificationAction(ffActionShareID) }
        }
        completionHandler()
    }
}

// MARK: - Notifications Screen (UI — fully redesigned)

struct NotificationsScreen: View {

    @EnvironmentObject private var appModel: AppModel

    @State private var settings: FFReminderSettings = .init()
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    private var todayQuoteFF: FFQuote {
        FFQuote(text: appModel.todayQuote.text, movie: appModel.todayQuote.movie)
    }

    private var todayTriviaFF: FFTrivia {
        let t = appModel.todayQuote.trivia
        let answer = (t.correctIndex >= 0 && t.correctIndex < t.choices.count) ? t.choices[t.correctIndex] : ""
        return FFTrivia(question: t.question, answer: answer)
    }

    private var quoteTimeBinding: Binding<Date> {
        Binding(
            get: { Self.makeDate(h: settings.quoteHour, m: settings.quoteMinute, isPM: settings.quoteIsPM) },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                let (h12, isPM) = Self.h12isPM(from24: comps.hour ?? 9)
                settings.quoteHour = h12
                settings.quoteMinute = comps.minute ?? 0
                settings.quoteIsPM = isPM
                persistAndReschedule()
            }
        )
    }

    private var triviaTimeBinding: Binding<Date> {
        Binding(
            get: { Self.makeDate(h: settings.triviaHour, m: settings.triviaMinute, isPM: settings.triviaIsPM) },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                let (h12, isPM) = Self.h12isPM(from24: comps.hour ?? 18)
                settings.triviaHour = h12
                settings.triviaMinute = comps.minute ?? 0
                settings.triviaIsPM = isPM
                persistAndReschedule()
            }
        )
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Permission status card
                    permissionCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    // Mode selector
                    modeSelectorCard
                        .padding(.horizontal, 16)

                    // Reminder config cards (conditional)
                    if settings.mode == .quoteOnly || settings.mode == .quoteAndTrivia {
                        reminderCard(
                            type: .quote,
                            timeBinding: quoteTimeBinding,
                            h12: settings.quoteHour,
                            minute: settings.quoteMinute,
                            isPM: settings.quoteIsPM
                        )
                        .padding(.horizontal, 16)
                    }

                    if settings.mode == .triviaOnly || settings.mode == .quoteAndTrivia {
                        reminderCard(
                            type: .trivia,
                            timeBinding: triviaTimeBinding,
                            h12: settings.triviaHour,
                            minute: settings.triviaMinute,
                            isPM: settings.triviaIsPM
                        )
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .onAppear {
            FFNotificationManager.shared.configure()
            let center = UNUserNotificationCenter.current()
            center.delegate = FFNotificationCenterDelegate.shared
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, err in
                if let err { print("🔔 Auth error: \(err)") }
                refreshAuthStatus()
            }
            if let stored = appModel.reminderSettingsBridge() {
                settings = stored
            } else if let migrated = migrateFromLegacyPrefs() {
                settings = migrated
                persist()
            }
            persistAndReschedule()
            refreshAuthStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshAuthStatus()
        }
    }

    // MARK: - Permission Card

    private var permissionCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(colorForStatus(authStatus).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: iconForStatus(authStatus))
                    .font(.title3)
                    .foregroundStyle(colorForStatus(authStatus))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(labelForStatus(authStatus))
                    .font(.subheadline.weight(.semibold))

                Text(authStatus == .denied
                     ? "Open Settings to re-enable notifications."
                     : "FilmFuel will deliver your daily reminders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if authStatus == .denied {
                Button("Fix") {
                    openSystemSettings()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.red)
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Mode Selector Card

    private var modeSelectorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What to send")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .font(.caption)

            HStack(spacing: 10) {
                ForEach(FFReminderMode.allCases) { mode in
                    modeButton(mode)
                }
            }

            if settings.mode != .off {
                Text(modeHelpText(settings.mode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func modeButton(_ mode: FFReminderMode) -> some View {
        let isSelected = settings.mode == mode

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                settings.mode = mode
            }
            persistAndReschedule()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: modeIcon(mode))
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .secondary)
                Text(modeShortLabel(mode))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? modeColor(mode) : Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private func modeIcon(_ mode: FFReminderMode) -> String {
        switch mode {
        case .off:           return "bell.slash.fill"
        case .quoteOnly:     return "quote.bubble.fill"
        case .triviaOnly:    return "gamecontroller.fill"
        case .quoteAndTrivia: return "bell.badge.fill"
        }
    }

    private func modeShortLabel(_ mode: FFReminderMode) -> String {
        switch mode {
        case .off:           return "Off"
        case .quoteOnly:     return "Quote"
        case .triviaOnly:    return "Trivia"
        case .quoteAndTrivia: return "Both"
        }
    }

    private func modeColor(_ mode: FFReminderMode) -> Color {
        switch mode {
        case .off:           return Color(.systemGray)
        case .quoteOnly:     return .blue
        case .triviaOnly:    return .purple
        case .quoteAndTrivia: return .accentColor
        }
    }

    // MARK: - Reminder Card

    enum ReminderType { case quote, trivia }

    private func reminderCard(
        type: ReminderType,
        timeBinding: Binding<Date>,
        h12: Int,
        minute: Int,
        isPM: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(type == .quote ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: type == .quote ? "quote.bubble.fill" : "gamecontroller.fill")
                        .font(.subheadline)
                        .foregroundStyle(type == .quote ? .blue : .purple)
                }
                Text(type == .quote ? "Daily Quote" : "Daily Trivia")
                    .font(.headline)
                Spacer()
            }

            // Preview card
            previewCard(type: type)

            Divider()

            // Time picker
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Delivery Time")
                        .font(.subheadline.weight(.medium))
                    Text(nextFireDateText(h12: h12, m: minute, isPM: isPM))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func previewCard(type: ReminderType) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Simulated notification chrome
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "film.fill")
                        .font(.caption2)
                    Text("FILMFUEL")
                        .font(.caption2.weight(.bold))
                        .kerning(0.5)
                    Spacer()
                    Text("now")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.secondary)

                if type == .quote {
                    Text("🎬 Your Daily FilmFuel")
                        .font(.caption.weight(.semibold))
                    Text("\u{201C}\(todayQuoteFF.text)\u{201D} \u{2014} \(todayQuoteFF.movie)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("🎥 FilmFuel Trivia")
                        .font(.caption.weight(.semibold))
                    Text(todayTriviaFF.question)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Permission helpers (unchanged logic)

    private func refreshAuthStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async { self.authStatus = s.authorizationStatus }
        }
    }

    private func iconForStatus(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "bell.badge.fill"
        case .denied: return "bell.slash.fill"
        case .notDetermined: return "bell"
        @unknown default: return "bell"
        }
    }

    private func colorForStatus(_ status: UNAuthorizationStatus) -> Color {
        switch status {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        @unknown default: return .gray
        }
    }

    private func labelForStatus(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "Notifications Enabled"
        case .denied: return "Notifications Disabled"
        case .notDetermined: return "Permission Not Set"
        @unknown default: return "Notifications"
        }
    }

    private func openSystemSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        #endif
    }

    // MARK: - Persistence + Scheduling (unchanged logic)

    private func persist() { appModel.updateReminderSettingsBridge(settings) }

    private func persistAndReschedule() {
        persist()
        FFNotificationManager.shared.reschedule(settings: settings, quote: todayQuoteFF, trivia: todayTriviaFF)
    }

    // MARK: - Helpers (unchanged)

    private func nextFireDateText(h12: Int, m: Int, isPM: Bool) -> String {
        let hour24 = FFNotificationManager.hour24(from12h: h12, isPM: isPM)
        var comps = DateComponents()
        comps.hour = hour24
        comps.minute = m
        let next = Calendar.current.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTimePreservingSmallerComponents) ?? Date()
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
        if h24 == 0 { return (12, false) }
        if h24 == 12 { return (12, true) }
        if h24 > 12 { return (h24 - 12, true) }
        return (h24, false)
    }

    private func modeHelpText(_ mode: FFReminderMode) -> String {
        switch mode {
        case .off: return "Reminders are disabled."
        case .quoteOnly: return "Sends a daily quote with the movie title."
        case .triviaOnly: return "Sends the daily trivia question."
        case .quoteAndTrivia: return "Sends both a quote and a trivia question at their set times."
        }
    }

    private func migrateFromLegacyPrefs() -> FFReminderSettings? {
        let d = UserDefaults.standard
        let hour24 = d.integer(forKey: Prefs.reminderHourKey)
        let minute = d.integer(forKey: Prefs.reminderMinuteKey)
        let rawMode = d.integer(forKey: Prefs.reminderModeKey)
        guard (hour24 > 0 || minute > 0) else { return nil }
        var mode: FFReminderMode = .quoteOnly
        if let legacy = ReminderContentMode(rawValue: rawMode) {
            switch legacy {
            case .triviaOnly: mode = .triviaOnly
            case .triviaAndQuote: mode = .quoteAndTrivia
            case .quoteOnly: mode = .quoteOnly
            }
        }
        let (h12, isPM) = Self.h12isPM(from24: hour24)
        return FFReminderSettings(mode: mode, quoteHour: h12, quoteMinute: minute, quoteIsPM: isPM, triviaHour: 6, triviaMinute: 0, triviaIsPM: true)
    }
}

// MARK: - AppModel bridges (unchanged)

extension AppModel {
    private var groupID: String { "group.com.chrisolah.FilmFuel" }
    private var settingsKey: String { "ff.reminder.settings" }

    func reminderSettingsBridge() -> FFReminderSettings? {
        guard let data = UserDefaults(suiteName: groupID)?.data(forKey: settingsKey) else { return nil }
        return try? JSONDecoder().decode(FFReminderSettings.self, from: data)
    }

    func updateReminderSettingsBridge(_ settings: FFReminderSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults(suiteName: groupID)?.set(data, forKey: settingsKey)
    }
}
