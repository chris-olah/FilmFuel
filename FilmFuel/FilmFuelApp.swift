import SwiftUI
import UserNotifications

@main
struct FilmFuelApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var appModel = AppModel()
    @StateObject private var store = FilmFuelStore()
    @StateObject private var entitlements = FilmFuelEntitlements()

    init() {
        // Count launches + unique days used
        StatsManager.shared.trackAppLaunched()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appModel)
                .environmentObject(store)
                .environmentObject(entitlements)
                .preferredColorScheme(.dark)
                .onAppear {
                    StatsManager.shared.trackAppLaunched()
                    // Sync initial Plus state
                    entitlements.isPlus = store.isPlus
                }
                .onChange(of: store.isPlus) { _, newValue in
                    // Whenever StoreKit reports a new entitlement, update entitlements
                    entitlements.isPlus = newValue
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Show banner/sound even while app is in foreground
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
