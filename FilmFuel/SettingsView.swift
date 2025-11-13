import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    var onShowTipJar: (() -> Void)? = nil

    @State private var showDevActions = false
    @State private var showToast = false
    @State private var toastText = ""

    var body: some View {
        ZStack {
            List {
                // Navigate to Notifications screen
                Section(header: Text("Preferences")) {
                    NavigationLink {
                        NotificationsScreen()
                            .environmentObject(appModel)
                    } label: {
                        Label("Notifications", systemImage: "bell.badge")
                    }
                }

                // Tip Jar
                Section("Support") {
                    NavigationLink {
                        TipJarView()   // <-- new Tip Jar screen with custom amounts
                    } label: {
                        Label("Tip Jar", systemImage: "heart.circle.fill")
                    }
                }

                // About (+ hidden dev unlock)
                Section("About") {
                    Text(versionString)
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 5) {
                            showDevActions = true
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            #endif
                        }

                    Text("Daily iconic movie quotes and trivia.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showDevActions = true } label: { Image(systemName: "gear") }
                        .accessibilityLabel("Developer Actions")
                }
                #endif
            }
            .confirmationDialog("Developer Actions",
                                isPresented: $showDevActions,
                                titleVisibility: .visible) {
                Button("Reset ALL (Debug)", role: .destructive) { appModel.debugResetAll() }
                Button("Clear Today Completion") { appModel.debugClearTodayCompletion() }
                Button("Set Yesterday Completed") { appModel.debugSetYesterdayCompleted() }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(v) (\(b))"
    }
}
