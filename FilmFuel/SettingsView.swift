//
//  SettingsView.swift
//  FilmFuel
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

    private let appStoreID = "6755317910"
    private let supportEmail = "chrisolahfilmfuel@gmail.com"

    @State private var isShowingMailComposer = false
    @State private var showPaywall = false
    @State private var headerAppeared = false

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                        .padding(.bottom, 8)

                    if !entitlements.isPlus {
                        premiumBanner
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                    }

                    settingsBody
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                headerAppeared = true
            }
        }
        .sheet(isPresented: $isShowingMailComposer) {
            MailView(
                recipients: [supportEmail],
                subject: "FilmFuel Feedback",
                body: "Hey Chris,\n\nI had some feedback about FilmFuel:\n\n"
            )
        }
        .sheet(isPresented: $showPaywall) {
            FilmFuelPlusPaywallView()
                .environmentObject(store)
                .environmentObject(entitlements)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        ZStack(alignment: .bottom) {
            // Cinematic gradient background
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)

            // Film grain overlay feel
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.accentColor.opacity(0.08), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 160)

            VStack(spacing: 10) {
                // Avatar / Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.accentColor.opacity(0.3), .accentColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)

                    Image(systemName: entitlements.isPlus ? "crown.fill" : "film.fill")
                        .font(.title2)
                        .foregroundStyle(entitlements.isPlus ? .yellow : .accentColor)
                }
                .scaleEffect(headerAppeared ? 1 : 0.6)
                .opacity(headerAppeared ? 1 : 0)

                // Level + XP bar
                xpProgressView
                    .opacity(headerAppeared ? 1 : 0)
                    .offset(y: headerAppeared ? 0 : 10)
            }
            .padding(.bottom, 20)
        }
    }

    private var xpProgressView: some View {
        let stats = StatsManager.shared
        let xp = stats.totalXP
        let level = UserLevel.level(for: xp)
        let nextLevel = level.next
        let currentXP = xp - level.requiredXP
        let neededXP = (nextLevel?.requiredXP ?? level.requiredXP + 500) - level.requiredXP
        let progress = neededXP > 0 ? min(1.0, Double(currentXP) / Double(neededXP)) : 1.0

        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(level.title)
                    .font(.subheadline.weight(.semibold))

                if entitlements.isPlus {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                        Text("Plus")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.yellow.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            // XP bar
            if let next = nextLevel {
                VStack(spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray5))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(
                                    colors: [.accentColor, .accentColor.opacity(0.7)],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: geo.size.width * progress, height: 6)
                        }
                    }
                    .frame(width: 160, height: 6)

                    Text("\(xp) XP · \(next.requiredXP - xp) to \(next.title)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Premium Banner

    private var premiumBanner: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 48, height: 48)
                    Image(systemName: "crown.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Unlock FilmFuel+")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Smart picks · Unlimited trivia · Hidden Gems")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.yellow.opacity(0.4), .orange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Settings Body

    private var settingsBody: some View {
        VStack(spacing: 20) {
            preferencesSection
            librarySection
            insightsSection
            supportSection
            aboutSection
        }
    }

    // MARK: - Sections

    private var preferencesSection: some View {
        SettingsSection(title: "Preferences") {
            SettingsNavRow(
                icon: "bell.badge.fill",
                iconColor: .red,
                title: "Notifications",
                subtitle: "Daily quote & trivia reminders"
            ) {
                NotificationsScreen()
                    .environmentObject(appModel)
            }
        }
    }

    private var librarySection: some View {
        SettingsSection(title: "Library") {
            SettingsNavRow(
                icon: "heart.fill",
                iconColor: .pink,
                title: "Saved Quotes",
                subtitle: "Quotes you've collected"
            ) {
                FavoritesScreen()
            }

            Divider().padding(.leading, 52)

            SettingsNavRow(
                icon: "film.stack.fill",
                iconColor: .accentColor,
                title: "Want to Watch",
                subtitle: "Your saved movie list"
            ) {
                // Replace with your WantToWatchView once created
                EmptyView()
            }
        }
    }

    private var insightsSection: some View {
        SettingsSection(title: "Insights") {
            SettingsNavRow(
                icon: "chart.bar.xaxis",
                iconColor: .purple,
                title: "Your Stats",
                subtitle: "Streaks, accuracy & activity"
            ) {
                StatsView()
                    .environmentObject(entitlements)
            }

            Divider().padding(.leading, 52)

            NavigationLink {
                AchievementsView()
                    .environmentObject(appModel)
                    .environmentObject(entitlements)
            } label: {
                HStack(spacing: 14) {
                    iconPill(systemName: "trophy.fill", color: .yellow)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Achievements")
                            .font(.subheadline.weight(.medium))
                        Text("Track your milestones")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Badge with count
                    let unlocked = AchievementDefinition.unlockedAchievements().count
                    let total = AchievementDefinition.all.count
                    Text("\(unlocked)/\(total)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var supportSection: some View {
        SettingsSection(title: "Support") {
            SettingsNavRow(
                icon: "heart.circle.fill",
                iconColor: .red,
                title: "Tip Jar",
                subtitle: "Support FilmFuel's development"
            ) {
                TipJarView()
            }

            Divider().padding(.leading, 52)

            SettingsButtonRow(
                icon: "star.fill",
                iconColor: .yellow,
                title: "Rate FilmFuel",
                subtitle: "Leave a review on the App Store"
            ) {
                openAppStoreReviewPage()
            }

            Divider().padding(.leading, 52)

            SettingsButtonRow(
                icon: "envelope.fill",
                iconColor: .blue,
                title: "Send Feedback",
                subtitle: "Email Chris directly"
            ) {
                sendFeedbackTapped()
            }

            Divider().padding(.leading, 52)

            SettingsButtonRow(
                icon: "square.and.arrow.up",
                iconColor: .green,
                title: "Share FilmFuel",
                subtitle: "Tell your friends"
            ) {
                shareApp()
            }
        }
    }

    private var aboutSection: some View {
        SettingsSection(title: "About") {
            HStack {
                iconPill(systemName: "info.circle.fill", color: Color(.systemGray))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version")
                        .font(.subheadline.weight(.medium))
                    Text(versionString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)

            if entitlements.isPlus {
                Divider().padding(.leading, 52)
                HStack {
                    iconPill(systemName: "checkmark.seal.fill", color: .green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Subscription")
                            .font(.subheadline.weight(.medium))
                        Text("FilmFuel+ Active")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
            }

            Divider().padding(.leading, 52)

            HStack {
                iconPill(systemName: "film.fill", color: .accentColor)
                Text("Daily iconic movie quotes and trivia to fuel your film passion.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
        }
    }

    // MARK: - Shared icon pill

    private func iconPill(systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(width: 30, height: 30)
            Image(systemName: systemName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
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
        let urlString = "https://apps.apple.com/app/id\(appStoreID)?action=write-review"
        if let url = URL(string: urlString) { UIApplication.shared.open(url) }
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
        let subject = "FilmFuel Feedback"
        let body = "Hey Chris,\n\nI had some feedback about FilmFuel:"
        let encoded = "mailto:\(supportEmail)?subject=\(subject.urlEncoded)&body=\(body.urlEncoded)"
        if let url = URL(string: encoded) { UIApplication.shared.open(url) }
        #endif
    }

    private func shareApp() {
        #if canImport(UIKit)
        let text = "🎬 Check out FilmFuel — daily movie quotes and trivia to fuel your film passion!\n\nhttps://apps.apple.com/app/id\(appStoreID)"
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(vc, animated: true)
        }
        #endif
    }
}

// MARK: - Reusable Row Components

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

struct SettingsNavRow<Destination: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            rowContent
        }
        .buttonStyle(.plain)
    }

    private var rowContent: some View {
        HStack(spacing: 14) {
            iconPill
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    private var iconPill: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(iconColor)
                .frame(width: 30, height: 30)
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
    }
}

struct SettingsButtonRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                iconPill
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var iconPill: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(iconColor)
                .frame(width: 30, height: 30)
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - String helper

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

// MARK: - MailView

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

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
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
