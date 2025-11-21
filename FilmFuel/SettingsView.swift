import SwiftUI
import MessageUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    var onShowTipJar: (() -> Void)? = nil

    // Your App Store App ID (Apple ID from App Store Connect)
    private let appStoreID = "6755317910"

    // Where feedback emails go — change to your real support email
    private let supportEmail = "chrisolahfilmfuel@gmail.com"

    @State private var isShowingMailComposer = false

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

                // Support (Tip Jar + Rate FilmFuel + Send Feedback)
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
                    }

                    Button {
                        sendFeedbackTapped()
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                }

                // About
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
    }

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    // MARK: - Open App Store review page

    private func openAppStoreReviewPage() {
        #if canImport(UIKit)
        guard !appStoreID.isEmpty else { return }
        let urlString = "https://apps.apple.com/app/id\(appStoreID)?action=write-review"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    // MARK: - Feedback handling

    private func sendFeedbackTapped() {
        if MFMailComposeViewController.canSendMail() {
            // Show in-app mail composer
            isShowingMailComposer = true
        } else {
            // Fallback: open Mail / other client via mailto:
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
            dismiss()   // Close the sheet
        }
    }
}
