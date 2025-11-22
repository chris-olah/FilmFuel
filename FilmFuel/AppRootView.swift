import SwiftUI

enum RootTab: Hashable {
    case home, quiz, discover, settings
}

struct AppRootView: View {
    @StateObject private var appModel = AppModel()

    @State private var selectedTab: RootTab = .home
    @State private var showTipJar: Bool = false

    // MARK: - Onboarding
    @AppStorage("ff.hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var showOnboarding: Bool = false

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {

                // HOME
                HomeView(onStartQuiz: { selectedTab = .quiz })
                    .environmentObject(appModel)
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(RootTab.home)

                // QUIZ
                QuizView()
                    .environmentObject(appModel)
                    .tabItem { Label("Quiz", systemImage: "popcorn.fill") }
                    .if(!appModel.quizCompletedToday) { view in
                        view.badge(1)   // 🔴 small red badge while not completed
                    }
                    .tag(RootTab.quiz)

                // DISCOVER (TMDB-powered movie explore)
                DiscoverView()
                    .tabItem { Label("Discover", systemImage: "sparkles") }
                    .tag(RootTab.discover)

                // SETTINGS
                SettingsView(onShowTipJar: { showTipJar = true })
                    .environmentObject(appModel)
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(RootTab.settings)
            }
            .sheet(isPresented: $showTipJar) {
                NavigationStack {
                    TipJarView()
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            // Deep links (e.g., filmfuel://quiz, filmfuel://discover, filmfuel://settings, filmfuel://tipjar, filmfuel://home)
            .onOpenURL { url in
                handleDeepLink(url)
            }
            // Live route from notification actions when app is already active
            .onReceive(NotificationCenter.default.publisher(for: .filmFuelOpenQuiz)) { _ in
                selectedTab = .quiz
            }
            // Configure notifications early and consume any pending route (cold launch)
            .task {
                FFNotificationManager.shared.configure()
                consumePendingRouteIfAny()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                consumePendingRouteIfAny()
            }
            // Decide whether to show onboarding
            .onAppear {
                if !hasSeenOnboarding {
                    showOnboarding = true
                }
            }
            // Full-screen onboarding on first launch
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView()
                    .environmentObject(appModel)
            }
        }
    }

    // MARK: - Pending route consumption
    private func consumePendingRouteIfAny() {
        if let route = FFRouteInbox.shared.consume() {
            switch route {
            case "quiz":
                selectedTab = .quiz
            case "share-quote":
                selectedTab = .home
                // HomeView listens for this to open share sheet
                NotificationCenter.default.post(name: .filmFuelShareQuote, object: nil)
            default:
                break
            }
        }
    }

    // MARK: - Deep Link Router
    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "filmfuel" else { return }
        let host = (url.host ?? "").lowercased()

        switch host {
        case "quiz":
            selectedTab = .quiz
        case "discover":
            selectedTab = .discover
        case "settings":
            selectedTab = .settings
        case "tipjar":
            selectedTab = .settings
            showTipJar = true
        case "home", "":
            selectedTab = .home
        default:
            selectedTab = .home
        }
    }
}

// MARK: - Small helper: conditional modifier
private extension View {
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
