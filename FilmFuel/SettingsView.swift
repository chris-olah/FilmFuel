import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    var onShowTipJar: (() -> Void)? = nil

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
                    } label: {
                        Label("Notifications", systemImage: "bell.badge")
                    }
                }

                // Library (Saved Quotes)
                Section(
                    header: Text("Library"),
                    footer: Text("Browse all the quotes you've saved while discovering movies.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                ) {
                    NavigationLink {
                        FavoritesScreen()
                    } label: {
                        Label("Saved Quotes", systemImage: "heart.fill")
                    }
                }

                // Insights / Stats
                Section(
                    header: Text("Insights"),
                    footer: Text("See your trivia accuracy, streaks, and how often you’ve been using FilmFuel.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                ) {
                    NavigationLink {
                        StatsView()
                    } label: {
                        Label("Your Stats", systemImage: "chart.bar.xaxis")
                    }
                }

                // Support (Tip Jar)
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

                // About section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(versionString)
                            .foregroundStyle(.secondary)
                    }

                    Text("Daily iconic movie quotes and trivia to keep you inspired.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
    }

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
