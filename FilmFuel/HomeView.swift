import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var showingShare = false

    // Track streak changes (for toasts/haptics)
    @State private var prevCorrectStreak: Int = 0
    @State private var prevBestCorrectStreak: Int = 0

    // Toast state (currently unused, but kept in case you want to re-enable later)
    @State private var showMilestoneToast = false
    @State private var milestoneText = ""

    /// Callback from parent to open the Quiz screen via NavigationStack/Tab switch
    var onStartQuiz: (() -> Void)? = nil

    // MARK: - Derived

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "☀️ Morning"
        case 12..<17: return "🌤️ Afternoon"
        case 17..<23: return "🌙 Evening"
        default:      return "👋 Welcome"
        }
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // CONTENT
            VStack(alignment: .leading, spacing: 0) {

                // ===== HEADER (title left, pills + share right) =====
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FilmFuel")
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(greetingText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .layoutPriority(10) // make sure this wins space

                    Spacer(minLength: 8)

                    // Pills on the right; scroll if needed
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            StreakPill(
                                title: "Daily",
                                value: appModel.dailyStreak,
                                icon: "calendar"
                            )
                            StreakPill(
                                title: "Correct",
                                value: appModel.correctStreak,
                                icon: "flame.fill",
                                showRecord: appModel.correctStreak > 0
                                    && appModel.correctStreak == appModel.bestCorrectStreak
                            )
                        }
                        .padding(.trailing, 2)
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    // Share (top-right global action)
                    Button {
                        showingShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .imageScale(.medium)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Give the hero zone some air
                Spacer(minLength: 10)

                // HERO QUOTE CARD (no "Today’s quote" label above)
                QuoteCard(
                    text: appModel.todayQuote.text,
                    movie: appModel.todayQuote.movie,
                    year: appModel.todayQuote.year
                )
                .padding(.top, 2)
                .padding(.bottom, 4)

                // STREAK READOUT — center "Correct …" (protected), let Day/Best flex
                HStack(alignment: .firstTextBaseline, spacing: 10) {

                    // Left: Day (flexible)
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text("Day \(String(appModel.dailyStreak))")
                    }
                    .font(.footnote).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    // Center: Correct (protected)
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .imageScale(.small)
                        Text("Correct \(String(appModel.correctStreak))")
                            .allowsTightening(true)
                            .lineLimit(1)
                            .minimumScaleFactor(0.96)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(3)
                    }
                    .font(.footnote).monospacedDigit()
                    .foregroundStyle(.secondary)

                    // Right: Best (flexible)
                    HStack(spacing: 4) {
                        Image(systemName: "trophy")
                        Text("Best \(String(appModel.bestCorrectStreak))")
                    }
                    .font(.footnote).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .padding(.horizontal)

                // Create a strong “stage” gap before CTA
                Spacer(minLength: 18)

                // CTA
                if !appModel.quizCompletedToday {
                    Button {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        onStartQuiz?()
                    } label: {
                        VStack(spacing: 4) {
                            Label("Take Today’s Quiz", systemImage: "gamecontroller.fill")
                                .font(.headline)
                            Text("1 quick question • keep your streak alive")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [Color.black, Color(.darkGray)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        )
                        .foregroundStyle(.white)
                        .shadow(radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .accessibilityIdentifier("startQuizButton")
                } else {
                    VStack(spacing: 4) {
                        Label("You’ve played today", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text("Come back tomorrow for a new question.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityHint("New quiz appears tomorrow.")
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 2)
                }

                // Soften the landing before the bottom
                Spacer(minLength: 16)
            }

            // ===== TOAST DISABLED =====
            /*
            if showMilestoneToast {
                VStack {
                    MilestoneToast(text: milestoneText)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                    Spacer()
                }
                .padding(.horizontal)
            }
            */
        }
        // Share sheet (uses your existing ShareSheet type)
        .sheet(isPresented: $showingShare) {
            ShareSheet(activityItems: [shareText()])
        }
        // Deep-link from notification action "Share Quote"
        .onReceive(NotificationCenter.default.publisher(for: .filmFuelShareQuote)) { _ in
            showingShare = true
        }
        // Freshen when foregrounded
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in
            appModel.refreshDailyStateIfNeeded()
        }
        .onAppear {
            appModel.refreshDailyStateIfNeeded()
            handleCorrectStreakChange(appModel.correctStreak)
            prevBestCorrectStreak = appModel.bestCorrectStreak
        }
        // iOS 17+ friendly onChange (zero-parameter closure)
        .onChange(of: appModel.correctStreak) {
            handleCorrectStreakChange(appModel.correctStreak)
        }
        .onChange(of: appModel.bestCorrectStreak) {
            prevBestCorrectStreak = appModel.bestCorrectStreak
        }
    }

    // MARK: - Change handler (haptics only, toast disabled)
    private func handleCorrectStreakChange(_ newValue: Int) {
        if prevCorrectStreak == 0 && newValue == 0 {
            prevCorrectStreak = 0
            return
        }
        guard newValue > prevCorrectStreak else {
            prevCorrectStreak = newValue
            return
        }

        let newRecord = newValue > prevBestCorrectStreak
        let milestone = isMilestone(newValue)

        if newRecord && milestone {
            triggerSuccessHaptic()
            milestoneText = "Milestone \(String(newValue))! 🔥 New Record!"
        } else if newRecord {
            triggerSuccessHaptic()
            milestoneText = "New Record \(String(newValue))! 🔥"
        } else if milestone {
            triggerSuccessHaptic()
            milestoneText = "Milestone \(String(newValue))! 🔥"
        } else {
            triggerLightPop()
        }

        prevCorrectStreak = newValue
        prevBestCorrectStreak = max(prevBestCorrectStreak, newValue)
    }

    private func dismissToastAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                showMilestoneToast = false
            }
        }
    }

    private func shareText() -> String {
        let q = appModel.todayQuote
        return "“\(q.text)” — \(q.movie) (\(q.year)) #FilmFuel"
    }

    // MARK: - Milestones & Haptics
    private func isMilestone(_ n: Int) -> Bool {
        let special = [5, 10, 25, 50, 100]
        return special.contains(n) || (n > 100 && n % 25 == 0)
    }

    private func triggerSuccessHaptic() {
        #if os(iOS)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif
    }

    private func triggerLightPop() {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        #endif
    }
}

// MARK: - Small subviews

private struct StreakPill: View {
    let title: String
    let value: Int
    let icon: String
    var showRecord: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .imageScale(.small)

            Text(title)
                .font(.footnote)
                .opacity(0.85)
                .lineLimit(1)
                .allowsTightening(true)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)

            Text("\(String(max(0, value)))")
                .font(.footnote).monospacedDigit().bold()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.12))
        .foregroundStyle(.orange)
        .clipShape(Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(2)
        .overlay(alignment: .topTrailing) {
            if showRecord {
                Image(systemName: "trophy.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.yellow)
                    .offset(x: 6, y: -2)
                    .accessibilityHidden(true)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showRecord)
        .accessibilityLabel("\(title) streak \(String(value)) days\(showRecord ? ", current record" : "")")
    }
}

private struct QuoteCard: View {
    let text: String
    let movie: String
    let year: Int

    var body: some View {
        VStack(spacing: 18) {
            Text("“\(text)”")
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .lineLimit(6)
                .minimumScaleFactor(0.84)
                .allowsTightening(true)

            VStack(spacing: 2) {
                Text(movie)
                    .font(.callout.weight(.semibold))
                    .opacity(0.9)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .truncationMode(.tail)
                Text(String(year)) // ensures no locale comma (e.g., 2,005)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
        .shadow(radius: 4, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text) — \(movie) \(String(year))")
    }
}

private struct MilestoneToast: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Text("🎉").font(.headline)
            Text(text).font(.subheadline).bold()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 320)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(radius: 8, y: 4)
        .padding(.horizontal)
        .accessibilityLabel(text)
    }
}
