import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var entitlements: FilmFuelEntitlements

    @State private var showingShare = false
    @State private var prevCorrectStreak: Int = 0
    @State private var prevBestCorrectStreak: Int = 0
    @State private var showMilestoneToast = false
    @State private var milestoneText = ""
    
    // New engagement states
    @State private var quoteAppeared = false
    @State private var statsAppeared = false
    @State private var ctaAppeared = false
    @State private var pulseQuizButton = false
    @State private var showStreakRisk = false
    
    var onStartQuiz: (() -> Void)? = nil

    // MARK: - Computed Properties
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Welcome back"
        }
    }
    
    private var motivationalSubtext: String {
        if appModel.correctStreak >= 10 {
            return "You're on fire! 🔥"
        } else if appModel.correctStreak >= 5 {
            return "Keep the momentum going!"
        } else if appModel.dailyStreak >= 7 {
            return "A week strong! 💪"
        } else if appModel.quizCompletedToday {
            return "See you tomorrow, cinephile"
        } else {
            return "Daily movie energy"
        }
    }
    
    private var streakAtRisk: Bool {
        // Show risk indicator if user hasn't played today and has an active streak
        !appModel.quizCompletedToday && appModel.dailyStreak > 0
    }

    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // ===== HEADER AREA =====
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    // ===== STREAK PILLS =====
                    streakPillsSection
                        .padding(.top, 12)
                    
                    // ===== HERO QUOTE CARD =====
                    QuoteCard(
                        text: appModel.todayQuote.text,
                        movie: appModel.todayQuote.movie,
                        year: appModel.todayQuote.year
                    )
                    .opacity(quoteAppeared ? 1 : 0)
                    .offset(y: quoteAppeared ? 0 : 20)
                    .padding(.top, 20)
                    
                    // ===== QUICK STATS =====
                    quickStatsBar
                        .padding(.top, 16)
                        .opacity(statsAppeared ? 1 : 0)
                        .offset(y: statsAppeared ? 0 : 15)
                    
                    // ===== CTA SECTION =====
                    ctaSection
                        .padding(.top, 24)
                        .opacity(ctaAppeared ? 1 : 0)
                        .scaleEffect(ctaAppeared ? 1 : 0.95)
                    
                    // ===== PREMIUM TEASER (if not subscribed) =====
                    if !entitlements.isPlus {
                        premiumTeaser
                            .padding(.top, 24)
                    }
                    
                    // ===== ACHIEVEMENTS PREVIEW =====
                    achievementsPreview
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                }
            }

            // Toast overlay
            if showMilestoneToast {
                VStack {
                    MilestoneToast(text: milestoneText)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showingShare) {
            ShareSheet(activityItems: [shareText()])
        }
        .onReceive(NotificationCenter.default.publisher(for: .filmFuelShareQuote)) { _ in
            showingShare = true
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in
            appModel.refreshDailyStateIfNeeded()
        }
        .onAppear {
            appModel.refreshDailyStateIfNeeded()
            handleCorrectStreakChange(appModel.correctStreak)
            prevBestCorrectStreak = appModel.bestCorrectStreak
            
            // Staggered entrance animations
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                quoteAppeared = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25)) {
                statsAppeared = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
                ctaAppeared = true
            }
            
            // Start pulse animation for CTA if quiz not completed
            if !appModel.quizCompletedToday {
                startPulseAnimation()
            }
        }
        .onChange(of: appModel.correctStreak) {
            handleCorrectStreakChange(appModel.correctStreak)
        }
        .onChange(of: appModel.bestCorrectStreak) {
            prevBestCorrectStreak = appModel.bestCorrectStreak
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("FILMFUEL")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(motivationalSubtext)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .layoutPriority(10)

            Spacer(minLength: 8)

            Button {
                showingShare = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .imageScale(.medium)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }
        }
    }
    
    // MARK: - Streak Pills Section
    
    private var streakPillsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                StreakPill(
                    title: "Daily",
                    value: appModel.dailyStreak,
                    icon: "calendar",
                    isAtRisk: streakAtRisk
                )
                
                StreakPill(
                    title: "Correct",
                    value: appModel.correctStreak,
                    icon: "flame.fill",
                    showRecord: appModel.correctStreak > 0
                        && appModel.correctStreak == appModel.bestCorrectStreak
                )
                
                // New: Best streak pill
                if appModel.bestCorrectStreak > 0 {
                    StreakPill(
                        title: "Best",
                        value: appModel.bestCorrectStreak,
                        icon: "trophy.fill",
                        accentColor: .yellow
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Quick Stats Bar
    
    private var quickStatsBar: some View {
        HStack(spacing: 0) {
            quickStatItem(
                icon: "calendar",
                label: "Day",
                value: "\(appModel.dailyStreak)"
            )
            
            Divider()
                .frame(height: 24)
                .opacity(0.3)
            
            quickStatItem(
                icon: "flame.fill",
                label: "Streak",
                value: "\(appModel.correctStreak)"
            )
            
            Divider()
                .frame(height: 24)
                .opacity(0.3)
            
            quickStatItem(
                icon: "trophy",
                label: "Best",
                value: "\(appModel.bestCorrectStreak)"
            )
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
    }
    
    private func quickStatItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .imageScale(.small)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - CTA Section
    
    private var ctaSection: some View {
        Group {
            if !appModel.quizCompletedToday {
                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    onStartQuiz?()
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "gamecontroller.fill")
                                .imageScale(.medium)
                            
                            Text("Take Today's Quiz")
                                .font(.headline.weight(.bold))
                            
                            if streakAtRisk {
                                Text("🔥")
                                    .font(.caption)
                            }
                        }
                        
                        Text("1 quick question • keep your streak alive")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        ZStack {
                            LinearGradient(
                                colors: [Color.orange, Color.red.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            // Shimmer effect
                            if pulseQuizButton {
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.2), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .offset(x: pulseQuizButton ? 200 : -200)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    )
                    .foregroundStyle(.white)
                    .shadow(color: .orange.opacity(0.4), radius: 12, y: 6)
                    .scaleEffect(pulseQuizButton ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .accessibilityIdentifier("startQuizButton")
                
                // Streak risk warning
                if streakAtRisk {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .imageScale(.small)
                        
                        Text("Don't lose your \(appModel.dailyStreak)-day streak!")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                    .transition(.opacity)
                }
                
            } else {
                // Completed state with encouragement
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quiz Complete!")
                                .font(.subheadline.weight(.semibold))
                            
                            Text("Come back tomorrow for a new challenge")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.green.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    // Encourage endless mode
                    Button {
                        // Navigate to endless trivia
                    } label: {
                        HStack {
                            Image(systemName: "infinity")
                            Text("Play More Trivia")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .imageScale(.small)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Premium Teaser
    
    private var premiumTeaser: some View {
        Button {
            // Navigate to paywall
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock FilmFuel Pro")
                        .font(.subheadline.weight(.bold))
                    
                    Text("Ad-free • Unlimited trivia • Exclusive packs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.yellow.opacity(0.1),
                                Color.orange.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.yellow.opacity(0.5), .orange.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Achievements Preview
    
    private var achievementsPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.headline.weight(.bold))
                
                Spacer()
                
                Button {
                    // Navigate to full achievements
                } label: {
                    Text("See All")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    AchievementBadge(
                        icon: "flame.fill",
                        title: "Hot Streak",
                        subtitle: "5 correct in a row",
                        progress: min(1.0, Double(appModel.correctStreak) / 5.0),
                        isUnlocked: appModel.bestCorrectStreak >= 5
                    )
                    
                    AchievementBadge(
                        icon: "calendar.badge.checkmark",
                        title: "Week Warrior",
                        subtitle: "7-day streak",
                        progress: min(1.0, Double(appModel.dailyStreak) / 7.0),
                        isUnlocked: appModel.dailyStreak >= 7
                    )
                    
                    AchievementBadge(
                        icon: "star.fill",
                        title: "Rising Star",
                        subtitle: "10 correct streak",
                        progress: min(1.0, Double(appModel.bestCorrectStreak) / 10.0),
                        isUnlocked: appModel.bestCorrectStreak >= 10
                    )
                    
                    AchievementBadge(
                        icon: "trophy.fill",
                        title: "Champion",
                        subtitle: "25 correct streak",
                        progress: min(1.0, Double(appModel.bestCorrectStreak) / 25.0),
                        isUnlocked: appModel.bestCorrectStreak >= 25,
                        isPremium: true
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Helper Methods
    
    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            pulseQuizButton = true
        }
    }
    
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
            milestoneText = "🏆 Milestone \(newValue)! New Record!"
            showToast()
        } else if newRecord {
            triggerSuccessHaptic()
            milestoneText = "🔥 New Record: \(newValue)!"
            showToast()
        } else if milestone {
            triggerSuccessHaptic()
            milestoneText = "🎯 Milestone: \(newValue)!"
            showToast()
        } else {
            triggerLightPop()
        }

        prevCorrectStreak = newValue
        prevBestCorrectStreak = max(prevBestCorrectStreak, newValue)
    }
    
    private func showToast() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showMilestoneToast = true
        }
        dismissToastAfterDelay()
    }

    private func dismissToastAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                showMilestoneToast = false
            }
        }
    }

    private func shareText() -> String {
        let q = appModel.todayQuote
        return "\"\(q.text)\" — \(q.movie) (\(q.year))\n\n🎬 Playing FilmFuel daily trivia!\n🔥 Current streak: \(appModel.correctStreak)"
    }

    private func isMilestone(_ n: Int) -> Bool {
        let special = [5, 10, 25, 50, 100]
        return special.contains(n) || (n > 100 && n % 25 == 0)
    }

    private func triggerSuccessHaptic() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func triggerLightPop() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - Animated Gradient Background

private struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.secondarySystemBackground),
                Color(.systemBackground)
            ],
            startPoint: animateGradient ? .topLeading : .topTrailing,
            endPoint: animateGradient ? .bottomTrailing : .bottomLeading
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 8)
                .repeatForever(autoreverses: true)
            ) {
                animateGradient = true
            }
        }
    }
}

// MARK: - Enhanced Streak Pill

private struct StreakPill: View {
    let title: String
    let value: Int
    let icon: String
    var showRecord: Bool = false
    var isAtRisk: Bool = false
    var accentColor: Color = .orange

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .imageScale(.small)
                .symbolEffect(.pulse, options: .repeating, isActive: isAtRisk)

            Text(title)
                .font(.footnote.weight(.medium))
                .opacity(0.85)
                .lineLimit(1)
                .allowsTightening(true)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)

            Text("\(max(0, value))")
                .font(.footnote.monospacedDigit().bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(accentColor.opacity(isAtRisk ? 0.2 : 0.12))
        )
        .foregroundStyle(accentColor)
        .overlay(
            Capsule()
                .stroke(isAtRisk ? accentColor.opacity(0.5) : .clear, lineWidth: 1.5)
        )
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(2)
        .overlay(alignment: .topTrailing) {
            if showRecord {
                Image(systemName: "trophy.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.yellow)
                    .offset(x: 6, y: -4)
                    .accessibilityHidden(true)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showRecord)
        .accessibilityLabel("\(title) streak \(value) days\(showRecord ? ", current record" : "")\(isAtRisk ? ", at risk" : "")")
    }
}

// MARK: - Enhanced Quote Card

private struct QuoteCard: View {
    let text: String
    let movie: String
    let year: Int
    
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 20) {
            // Quote marks decoration
            Image(systemName: "quote.opening")
                .font(.title2)
                .foregroundStyle(.orange.opacity(0.6))
            
            Text(text)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .lineLimit(6)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)

            VStack(spacing: 4) {
                Text(movie)
                    .font(.callout.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .truncationMode(.tail)
                
                Text(String(year))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 20)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text) — \(movie) \(String(year))")
    }
}

// MARK: - Achievement Badge

private struct AchievementBadge: View {
    let icon: String
    let title: String
    let subtitle: String
    let progress: Double
    let isUnlocked: Bool
    var isPremium: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Progress ring
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                    .frame(width: 56, height: 56)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isUnlocked ? Color.green : Color.orange,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                
                // Icon
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                
                // Lock overlay for premium
                if isPremium && !isUnlocked {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 90)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isUnlocked ? Color.green.opacity(0.1) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isUnlocked ? Color.green.opacity(0.3) : .clear, lineWidth: 1)
        )
    }
}

// MARK: - Milestone Toast

private struct MilestoneToast: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(text)
                .font(.subheadline.weight(.bold))
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
        .accessibilityLabel(text)
    }
}
