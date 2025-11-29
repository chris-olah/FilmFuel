//
//  FilmFuelApp.swift
//  FilmFuel
//
//  Enhanced with engagement tracking, smart notifications, deep linking,
//  and retention hooks for maximum user engagement
//

import SwiftUI
import UserNotifications
import StoreKit

@main
struct FilmFuelApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var appModel = AppModel()
    @StateObject private var store = FilmFuelStore()
    @StateObject private var entitlements = FilmFuelEntitlements()
    
    @Environment(\.scenePhase) private var scenePhase
    
    // Track session for engagement metrics
    @State private var sessionStartTime: Date?
    @State private var hasShownStreakCelebration = false
    
    init() {
        // Track app launch
        StatsManager.shared.trackAppLaunched()
        
        // Configure appearance
        configureAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appModel)
                .environmentObject(store)
                .environmentObject(entitlements)
                .preferredColorScheme(.dark)
                .onAppear {
                    handleAppear()
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(from: oldPhase, to: newPhase)
                }
                .onChange(of: store.isPlus) { _, newValue in
                    handlePlusStatusChange(newValue)
                }
                .onReceive(NotificationCenter.default.publisher(for: StatsManager.achievementUnlocked)) { notification in
                    handleAchievementUnlocked(notification)
                }
                .onReceive(NotificationCenter.default.publisher(for: StatsManager.levelUp)) { notification in
                    handleLevelUp(notification)
                }
                .onReceive(NotificationCenter.default.publisher(for: StatsManager.streakMilestone)) { notification in
                    handleStreakMilestone(notification)
                }
        }
    }
    
    // MARK: - Appearance Configuration
    
    private func configureAppearance() {
        // Navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor.systemBackground
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        
        // Tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
    
    // MARK: - Lifecycle Handlers
    
    private func handleAppear() {
        sessionStartTime = Date()
        StatsManager.shared.trackSessionStart()
        
        // Make sure entitlements reflect current StoreKit state at launch
        entitlements.setPlus(store.isPlus)
        
        // Request notification permissions after first meaningful engagement
        if StatsManager.shared.appLaunchCount >= 2 {
            requestNotificationPermissionIfNeeded()
        }
        
        // Check for streak celebration
        checkStreakCelebration()
        
        // Schedule re-engagement notifications
        scheduleEngagementNotifications()
    }
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active
            if oldPhase == .background {
                // Returning from background - check streak
                StatsManager.shared.trackAppLaunched()
                checkStreakCelebration()
            }
            
        case .inactive:
            // App is about to become inactive
            break
            
        case .background:
            // App went to background - record session duration
            if let start = sessionStartTime {
                let duration = Date().timeIntervalSince(start)
                recordSessionDuration(duration)
            }
            
            // Schedule return reminder if engaged user
            if StatsManager.shared.isHighlyEngaged {
                scheduleStreakReminderIfNeeded()
            }
            
        @unknown default:
            break
        }
    }
    
    private func handlePlusStatusChange(_ isPlus: Bool) {
        entitlements.setPlus(isPlus)
        
        if isPlus {
            // User just upgraded! Track and celebrate
            StatsManager.shared.addXP(100, reason: "Upgraded to FilmFuel+")
            
            // Cancel upgrade reminder notifications
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["upgrade_reminder", "trial_expiring"]
            )
        }
    }
    
    // MARK: - Streak Celebration
    
    private func checkStreakCelebration() {
        guard !hasShownStreakCelebration else { return }
        
        let streak = StatsManager.shared.currentStreak
        let milestones = [7, 14, 30, 50, 100]
        
        if milestones.contains(streak) {
            hasShownStreakCelebration = true
            // The celebration UI is handled by DiscoverView based on streak value
        }
    }
    
    // MARK: - Notification Management
    
    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .badge, .sound]
                ) { granted, error in
                    if granted {
                        print("✅ Notification permission granted")
                    }
                }
            }
        }
    }
    
    private func scheduleEngagementNotifications() {
        let center = UNUserNotificationCenter.current()
        
        // Remove old scheduled notifications first
        center.removePendingNotificationRequests(withIdentifiers: [
            "daily_trivia_reminder",
            "streak_at_risk",
            "weekly_recap",
            "new_movies_alert"
        ])
        
        // Only schedule if user has engaged before
        guard StatsManager.shared.appLaunchCount >= 3 else { return }
        
        // 1. Daily Trivia Reminder (if they've done trivia before)
        if StatsManager.shared.totalTriviaQuestionsAnswered > 0 {
            scheduleDailyTriviaReminder()
        }
        
        // 2. Weekly Recap (Sundays at 10am)
        scheduleWeeklyRecap()
        
        // 3. New Movies Alert (Fridays - new releases day)
        scheduleNewMoviesAlert()
    }
    
    private func scheduleDailyTriviaReminder() {
        let content = UNMutableNotificationContent()
        content.title = "🎬 Daily Trivia Ready!"
        content.body = "Test your movie knowledge and keep your streak going."
        content.sound = .default
        content.badge = 1
        
        // Schedule for 7 PM local time
        var dateComponents = DateComponents()
        dateComponents.hour = 19
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily_trivia_reminder",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func scheduleStreakReminderIfNeeded() {
        let streak = StatsManager.shared.currentStreak
        guard streak >= 3 else { return } // Only remind if they have a streak worth saving
        
        let content = UNMutableNotificationContent()
        content.title = "🔥 Don't lose your \(streak)-day streak!"
        content.body = "Open FilmFuel to keep your streak alive."
        content.sound = .default
        content.badge = 1
        
        // Schedule for 9 PM if they haven't opened today
        var dateComponents = DateComponents()
        dateComponents.hour = 21
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streak_at_risk",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func scheduleWeeklyRecap() {
        let stats = StatsManager.shared
        
        let content = UNMutableNotificationContent()
        content.title = "📊 Your Weekly FilmFuel Recap"
        content.body = "You discovered \(stats.discoverCardsViewed) movies this week! See your stats."
        content.sound = .default
        
        // Sunday at 10 AM
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 10
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "weekly_recap",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func scheduleNewMoviesAlert() {
        let content = UNMutableNotificationContent()
        content.title = "🍿 Fresh Movies Just Dropped!"
        content.body = "New releases are here. Discover your next favorite film."
        content.sound = .default
        
        // Friday at 6 PM
        var dateComponents = DateComponents()
        dateComponents.weekday = 6 // Friday
        dateComponents.hour = 18
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "new_movies_alert",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Session Tracking
    
    private func recordSessionDuration(_ duration: TimeInterval) {
        let minutes = Int(duration / 60)
        
        // Award XP for longer sessions
        if minutes >= 5 {
            StatsManager.shared.addXP(5, reason: "Quality session")
        }
        if minutes >= 15 {
            StatsManager.shared.addXP(10, reason: "Extended session")
        }
        
        // Track total time (could persist this)
        UserDefaults.standard.set(
            UserDefaults.standard.double(forKey: "ff.totalSessionTime") + duration,
            forKey: "ff.totalSessionTime"
        )
    }
    
    // MARK: - Event Handlers
    
    private func handleAchievementUnlocked(_ notification: Notification) {
        guard let id = notification.userInfo?["id"] as? String,
              let xp = notification.userInfo?["xp"] as? Int else { return }
        
        // Could show a toast or update UI
        print("🏆 Achievement unlocked: \(id) (+\(xp) XP)")
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func handleLevelUp(_ notification: Notification) {
        guard let newLevel = notification.userInfo?["newLevel"] as? Int else { return }
        
        print("⬆️ Level up! Now level \(newLevel)")
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func handleStreakMilestone(_ notification: Notification) {
        guard let streak = notification.userInfo?["streak"] as? Int,
              let bonusXP = notification.userInfo?["bonusXP"] as? Int else { return }
        
        print("🔥 Streak milestone: \(streak) days! (+\(bonusXP) XP)")
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Clear badge on launch using iOS 17+ API
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("Failed to clear badge: \(error)")
            }
        }
        
        // Configure StoreKit transaction listener
        Task {
            await listenForTransactions()
        }
        
        return true
    }
    
    // MARK: - Notification Delegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner/sound even while app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        
        // Track notification tap
        trackNotificationEngagement(identifier: identifier)
        
        // Handle deep linking based on notification type
        handleNotificationDeepLink(identifier: identifier)
        
        completionHandler()
    }
    
    private func trackNotificationEngagement(identifier: String) {
        // Track which notifications drive engagement
        let key = "ff.notification.taps.\(identifier)"
        let count = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(count, forKey: key)
        
        // Award small XP for returning via notification
        StatsManager.shared.addXP(2, reason: "Returned from notification")
    }
    
    private func handleNotificationDeepLink(identifier: String) {
        // Post notification for deep linking
        // AppRootView can observe this to navigate to the right screen
        NotificationCenter.default.post(
            name: Notification.Name("ff.deepLink"),
            object: nil,
            userInfo: ["destination": identifier]
        )
    }
    
    // MARK: - StoreKit Transaction Listener
    
    private func listenForTransactions() async {
        // Listen for transactions that happen outside the app
        for await result in Transaction.updates {
            do {
                let transaction = try checkVerified(result)
                
                // Update entitlements based on transaction
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .transactionUpdate,
                        object: nil,
                        userInfo: ["productID": transaction.productID]
                    )
                }
                
                await transaction.finish()
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    enum StoreError: Error {
        case failedVerification
    }
    
    // MARK: - Background Tasks
    
    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Could refresh movie data in background
        completionHandler(.noData)
    }
}

// MARK: - Notification Names used by the app layer

extension Notification.Name {
    // deepLink is posted using Notification.Name("ff.deepLink") above
    static let transactionUpdate = Notification.Name("ff.transactionUpdate")
}

// MARK: - Engagement Utilities

extension FilmFuelApp {
    
    /// Determines if we should show an upsell based on user behavior
    static var shouldShowContextualUpsell: Bool {
        let stats = StatsManager.shared
        
        // Don't annoy new users
        guard stats.appLaunchCount >= 5 else { return false }
        
        // Highly engaged free users are good candidates
        return stats.isHighlyEngaged && !UserDefaults.standard.bool(forKey: "ff.entitlements.isPlus")
    }
    
    /// Returns personalized upsell message based on user behavior
    static var contextualUpsellMessage: String {
        let stats = StatsManager.shared
        
        if stats.currentStreak >= 7 {
            return "You're on a \(stats.currentStreak)-day streak! Unlock unlimited features to keep it going."
        } else if stats.totalTriviaCorrect >= 50 {
            return "You've mastered \(stats.totalTriviaCorrect) trivia questions! Upgrade for exclusive challenges."
        } else if stats.discoverCardsViewed >= 100 {
            return "You've explored \(stats.discoverCardsViewed) movies! Get unlimited smart picks."
        } else {
            return "Unlock the full FilmFuel experience with Plus."
        }
    }
}
