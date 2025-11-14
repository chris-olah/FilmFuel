import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    var onShowTipJar: (() -> Void)? = nil

    @State private var showDevActions = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            List {
                // Preferences
                Section(
                    header: Text("Preferences"),
                    footer: Text("Customize when FilmFuel sends your daily quote and trivia reminders.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                ) {
                    NavigationLink {
                        NotificationsScreen()
                            .environmentObject(appModel)
                    } label: {
                        Label("Notifications", systemImage: "bell.badge")
                    }
                }

                // Support
                Section(
                    header: Text("Support"),
                    footer: Text("If FilmFuel helps keep you motivated, you can leave a small tip to support future updates.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                ) {
                    NavigationLink {
                        TipJarView()
                    } label: {
                        Label("Tip Jar", systemImage: "heart.circle.fill")
                    }
                }

                // ⭐️ NEW: Saved Quotes Library
                Section(
                    header: Text("Library"),
                    footer: Text("Browse all the quotes you've saved while discovering movies.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                ) {
                    NavigationLink {
                        FavoritesScreen()
                            .environmentObject(appModel)
                    } label: {
                        Label("Saved Quotes", systemImage: "heart.fill")
                    }
                }

                // About section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(versionString)
                            .foregroundStyle(.secondary)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 5) {
                                showDevActions = true
                                #if os(iOS)
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                #endif
                            }
                    }

                    Text("Daily iconic movie quotes and trivia to keep you inspired.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showDevActions = true } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel("Developer Actions")
                }
                #endif
            }
            .confirmationDialog(
                "Developer Actions",
                isPresented: $showDevActions,
                titleVisibility: .visible
            ) {
                Button("Reset ALL (Debug)", role: .destructive) {
                    appModel.debugResetAll()
                }
                Button("Clear Today Completion") {
                    appModel.debugClearTodayCompletion()
                }
                Button("Set Yesterday Completed") {
                    appModel.debugSetYesterdayCompleted()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
