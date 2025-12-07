//
//  SettingsView.swift
//  FilmFuel
//
//  UPDATED: Better organization, premium section, cleaner styling
//

import SwiftUI
import MessageUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var entitlements: FilmFuelEntitlements
    @EnvironmentObject var store: FilmFuelStore
    
    var onShowTipJar: (() -> Void)? = nil

    // Your App Store App ID (Apple ID from App Store Connect)
    private let appStoreID = "6755317910"

    // Where feedback emails go
    private let supportEmail = "chrisolahfilmfuel@gmail.com"

    @State private var isShowingMailComposer = false
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            List {
                // Premium Section (if not subscribed)
                if !entitlements.isPlus {
                    premiumSection
                }
                
                // Preferences
                preferencesSection
                
                // Library
                librarySection

                // Insights / Stats
                insightsSection

                // Support
                supportSection

                // About
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $isShowingMailComposer) {
            MailView(
                recipients: [supportEmail],
                subject: "FilmFuel Feedback",
                body: """
                Hey Chris, 
                
                I had some feedback about FilmFuel:
                """
            )
        }
        .sheet(isPresented: $showPaywall) {
            FilmFuelPlusPaywallView()
                .environmentObject(store)
                .environmentObject(entitlements)
        }
    }
    
    // MARK: - Premium Section
    
    private var premiumSection: some View {
        Section {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "crown.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upgrade to FilmFuel+")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Unlimited trivia • Smart picks • No ads")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
    
    // MARK: - Preferences Section
    
    private var preferencesSection: some View {
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
    }
    
    // MARK: - Library Section
    
    private var librarySection: some View {
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
    }
    
    // MARK: - Insights Section
    
    private var insightsSection: some View {
        Section(
            header: Text("Insights"),
            footer: Text("See your trivia accuracy, streaks, and how often you've been using FilmFuel.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        ) {
            NavigationLink {
                StatsView()
                    .environmentObject(entitlements)
            } label: {
                Label("Your Stats", systemImage: "chart.bar.xaxis")
            }
            
            NavigationLink {
                AchievementsView()
                    .environmentObject(appModel)
                    .environmentObject(entitlements)
            } label: {
                Label {
                    HStack {
                        Text("Achievements")
                        Spacer()
                        // Show count badge
                        let unlockedCount = AchievementDefinition.unlockedAchievements().count
                        let totalCount = AchievementDefinition.all.count
                        Text("\(unlockedCount)/\(totalCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "trophy.fill")
                }
            }
        }
    }
    
    // MARK: - Support Section
    
    private var supportSection: some View {
        Section(
            header: Text("Support"),
            footer: Text("If FilmFuel helps keep you motivated, you can leave a small tip, rating, or share feedback to support future updates.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        ) {
            NavigationLink {
                TipJarView()
            } label: {
                Label("Tip Jar", systemImage: "heart.circle.fill")
            }

            Button {
                openAppStoreReviewPage()
            } label: {
                Label("Rate FilmFuel", systemImage: "star.fill")
                    .foregroundColor(.primary)
            }

            Button {
                sendFeedbackTapped()
            } label: {
                Label("Send Feedback", systemImage: "envelope")
                    .foregroundColor(.primary)
            }
            
            // Share app
            Button {
                shareApp()
            } label: {
                Label("Share FilmFuel", systemImage: "square.and.arrow.up")
                    .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(versionString)
                    .foregroundStyle(.secondary)
            }
            
            if entitlements.isPlus {
                HStack {
                    Text("Subscription")
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("FilmFuel+")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text("Daily iconic movie quotes and trivia to keep you inspired.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers
    
    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func openAppStoreReviewPage() {
        #if canImport(UIKit)
        guard !appStoreID.isEmpty else { return }
        let urlString = "https://apps.apple.com/app/id\(appStoreID)?action=write-review"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    private func sendFeedbackTapped() {
        if MFMailComposeViewController.canSendMail() {
            isShowingMailComposer = true
        } else {
            openMailtoFallback()
        }
    }

    private func openMailtoFallback() {
        #if canImport(UIKit)
        guard !supportEmail.isEmpty else { return }

        let subject = "FilmFuel Feedback"
        let body = "Hey Chris,\n\nI had some feedback about FilmFuel:"

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body

        let urlString = "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
    
    private func shareApp() {
        #if canImport(UIKit)
        let shareText = "🎬 Check out FilmFuel - daily movie quotes and trivia to fuel your film passion!\n\nhttps://apps.apple.com/app/id\(appStoreID)"
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #endif
    }
}

// MARK: - MailView (in-app email composer)

struct MailView: UIViewControllerRepresentable {
    var recipients: [String]
    var subject: String
    var body: String

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppModel())
            .environmentObject(FilmFuelEntitlements())
            .environmentObject(FilmFuelStore())
    }
}
