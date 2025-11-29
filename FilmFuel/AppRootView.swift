//
//  AppRootView.swift
//  FilmFuel
//
//  Root with gamification overlays, smart upsells, and engagement hooks.
//  Stats has been moved out of the bottom tab bar and into Settings → Insights.
//

import SwiftUI

// MARK: - Root Tab

enum RootTab: Hashable {
    case home
    case quiz
    case discover
    case settings
}

// MARK: - App Root View

struct AppRootView: View {
    @StateObject private var appModel = AppModel()
    @EnvironmentObject var store: FilmFuelStore
    @EnvironmentObject var entitlements: FilmFuelEntitlements
    
    @State private var selectedTab: RootTab = .home
    @State private var showTipJar: Bool = false
    @State private var showPaywall: Bool = false
    
    // Onboarding
    @AppStorage("ff.hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var showOnboarding: Bool = false
    
    // Gamification overlays
    @State private var showXPToast: Bool = false
    @State private var xpToastAmount: Int = 0
    @State private var xpToastReason: String = ""
    
    // Streak warning
    @State private var showStreakWarning: Bool = false
    
    var body: some View {
        ZStack {
            NavigationStack {
                TabView(selection: $selectedTab) {
                    
                    // HOME
                    HomeView(onStartQuiz: { selectedTab = .quiz })
                        .environmentObject(appModel)
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }
                        .tag(RootTab.home)
                    
                    // QUIZ
                    QuizView()
                        .environmentObject(appModel)
                        .tabItem {
                            Label("Quiz", systemImage: "popcorn.fill")
                        }
                        .if(!appModel.quizCompletedToday) { view in
                            view.badge(1)
                        }
                        .tag(RootTab.quiz)
                    
                    // DISCOVER
                    DiscoverView(onTipTapped: { showTipJar = true })
                        .environmentObject(store)
                        .environmentObject(entitlements)
                        .tabItem {
                            Label("Discover", systemImage: "sparkles")
                        }
                        .tag(RootTab.discover)
                    
                    // SETTINGS (Stats now lives here under “Insights”)
                    SettingsView(onShowTipJar: { showTipJar = true })
                        .environmentObject(appModel)
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                        .tag(RootTab.settings)
                }
                .sheet(isPresented: $showTipJar) {
                    NavigationStack {
                        TipJarView()
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
                .sheet(isPresented: $showPaywall) {
                    FilmFuelPlusPaywallView()
                        .environmentObject(store)
                        .environmentObject(entitlements)
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .filmFuelOpenQuiz)) { _ in
                    selectedTab = .quiz
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: Notification.Name("ff.deepLink")
                    )
                ) { notification in
                    handleNotificationDeepLink(notification)
                }
                .task {
                    FFNotificationManager.shared.configure()
                    consumePendingRouteIfAny()
                    checkStreakStatus()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    consumePendingRouteIfAny()
                    appModel.refreshDailyStateIfNeeded()
                    checkStreakStatus()
                }
                .onAppear {
                    if !hasSeenOnboarding {
                        showOnboarding = true
                    }
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView()
                        .environmentObject(appModel)
                }
            }
            
            // MARK: - Gamification Overlays
            
            // XP Toast
            if showXPToast {
                xpToastOverlay
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
            
            // Achievement Unlocked
            if appModel.showAchievementUnlocked,
               let achievementId = appModel.lastUnlockedAchievement {
                achievementOverlay(achievementId)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(101)
            }
            
            // Level Up Celebration
            if appModel.showLevelUpCelebration,
               let level = appModel.newLevelReached {
                levelUpOverlay(level)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(102)
            }
            
            // Streak Warning
            if showStreakWarning {
                streakWarningOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(99)
            }
        }
        .animation(.spring(), value: showXPToast)
        .animation(.spring(), value: appModel.showAchievementUnlocked)
        .animation(.spring(), value: appModel.showLevelUpCelebration)
        .animation(.spring(), value: showStreakWarning)
        .onReceive(NotificationCenter.default.publisher(for: StatsManager.xpGained)) { notification in
            handleXPGain(notification)
        }
    }
    
    // MARK: - XP Toast Overlay
    
    private var xpToastOverlay: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                
                Text("+\(xpToastAmount) XP")
                    .font(.headline.weight(.bold))
                
                if !xpToastReason.isEmpty {
                    Text("• \(xpToastReason)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(radius: 10)
            .padding(.top, 60)
            
            Spacer()
        }
    }
    
    // MARK: - Achievement Overlay
    
    private func achievementOverlay(_ id: String) -> some View {
        let definition = AchievementDefinition.definition(for: id)
        
        return VStack {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: definition?.icon ?? "trophy.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.yellow)
                
                Text("Achievement Unlocked!")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(definition?.title ?? "Achievement")
                    .font(.title2.weight(.bold))
                
                Text(definition?.description ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if let xp = definition?.xpReward {
                    Text("+\(xp) XP")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
            .padding(24)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .background(Color.black.opacity(0.4).ignoresSafeArea())
        .onTapGesture {
            appModel.showAchievementUnlocked = false
        }
    }
    
    // MARK: - Level Up Overlay
    
    private func levelUpOverlay(_ level: Int) -> some View {
        let titles = ["Film Newbie", "Explorer", "Enthusiast", "Cinephile", "Connoisseur", "Elite Curator"]
        let icons = ["person.fill", "binoculars.fill", "star.fill", "film.fill", "crown.fill", "sparkles"]
        
        let title = level < titles.count ? titles[level] : "Legend"
        let icon = level < icons.count ? icons[level] : "sparkles"
        
        return VStack {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 56))
                    .foregroundColor(.accentColor)
                
                Text("Level Up!")
                    .font(.largeTitle.weight(.bold))
                
                Text("You're now a \(title)")
                    .font(.title3)
                
                Button {
                    appModel.dismissLevelUpCelebration()
                } label: {
                    Text("Awesome!")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(24)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .background(Color.black.opacity(0.5).ignoresSafeArea())
    }
    
    // MARK: - Streak Warning Overlay
    
    private var streakWarningOverlay: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep your streak alive!")
                        .font(.subheadline.weight(.semibold))
                    Text("Complete today's quiz before midnight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    showStreakWarning = false
                    selectedTab = .quiz
                } label: {
                    Text("Go")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                
                Button {
                    showStreakWarning = false
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleXPGain(_ notification: Notification) {
        guard let amount = notification.userInfo?["amount"] as? Int,
              amount >= 5 else { return } // Only show for significant XP gains
        
        xpToastAmount = amount
        xpToastReason = notification.userInfo?["reason"] as? String ?? ""
        showXPToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showXPToast = false
        }
    }
    
    private func checkStreakStatus() {
        let streak = StatsManager.shared.currentStreak
        let hour = Calendar.current.component(.hour, from: Date())
        
        // Show warning if:
        // - Has a streak of 3+ days
        // - It's evening (after 7 PM)
        // - Quiz not completed today
        if streak >= 3 && hour >= 19 && !appModel.quizCompletedToday {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showStreakWarning = true
            }
        }
    }
    
    // MARK: - Route Handling
    
    private func consumePendingRouteIfAny() {
        if let route = FFRouteInbox.shared.consume() {
            switch route {
            case "quiz":
                selectedTab = .quiz
            case "discover":
                selectedTab = .discover
            case "stats":
                // Stats moved into Settings → Insights
                selectedTab = .settings
            case "share-quote":
                selectedTab = .home
                NotificationCenter.default.post(name: .filmFuelShareQuote, object: nil)
            default:
                break
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "filmfuel" else { return }
        let host = (url.host ?? "").lowercased()
        
        switch host {
        case "quiz":
            selectedTab = .quiz
        case "discover":
            selectedTab = .discover
        case "stats":
            // Deep links to stats now land on Settings tab
            selectedTab = .settings
        case "settings":
            selectedTab = .settings
        case "tipjar":
            selectedTab = .settings
            showTipJar = true
        case "plus", "upgrade":
            showPaywall = true
        case "home", "":
            selectedTab = .home
        default:
            selectedTab = .home
        }
    }
    
    private func handleNotificationDeepLink(_ notification: Notification) {
        guard let destination = notification.userInfo?["destination"] as? String else { return }
        
        switch destination {
        case "daily_trivia_reminder", "streak_at_risk":
            selectedTab = .quiz
        case "weekly_recap":
            // Used to open Stats tab; now route to Settings where Stats lives
            selectedTab = .settings
        case "new_movies_alert":
            selectedTab = .discover
        default:
            break
        }
    }
}

// MARK: - Conditional Modifier

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool,
                             transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let filmFuelOpenQuiz = Notification.Name("ff.openQuiz")
    static let filmFuelShareQuote = Notification.Name("ff.shareQuote")
}
