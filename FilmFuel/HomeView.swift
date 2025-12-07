//
//  HomeView.swift
//  FilmFuel
//
//  UPDATED: Fixed premium teaser, removed duplicate streak display,
//  improved "Play More Trivia" CTA, fixed string encoding
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var entitlements: FilmFuelEntitlements
    @EnvironmentObject private var store: FilmFuelStore

    @State private var showingShare = false
    @State private var prevCorrectStreak: Int = 0
    @State private var prevBestCorrectStreak: Int = 0
    @State private var showMilestoneToast = false
    @State private var milestoneText = ""
    
    // Entrance / CTA
    @State private var quoteAppeared = false
    @State private var statsAppeared = false
    @State private var ctaAppeared = false
    @State private var pulseQuizButton = false
    
    // Achievements navigation
    @State private var showAllAchievements = false
    
    // NEW: Paywall state (was missing!)
    @State private var showPaywall = false
    
    /// Daily quiz
    var onStartQuiz: (() -> Void)? = nil
    
    /// Endless trivia (used by "Play More Trivia")
    var onStartEndlessTrivia: (() -> Void)? = nil

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
        !appModel.quizCompletedToday && appModel.dailyStreak > 0
    }

    // MARK: - Body
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            mainScrollView
            toastOverlay
        }
        .sheet(isPresented: $showingShare) {
            ShareSheet(activityItems: [shareText()])
        }
        .sheet(isPresented: $showAllAchievements) {
            NavigationStack {
                AchievementsView()
                    .environmentObject(appModel)
                    .environmentObject(entitlements)
            }
        }
        // NEW: Paywall sheet
        .sheet(isPresented: $showPaywall) {
            FilmFuelPlusPaywallView()
                .environmentObject(store)
                .environmentObject(entitlements)
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
            handleOnAppear()
        }
        .onChange(of: appModel.correctStreak) {
            handleCorrectStreakChange(appModel.correctStreak)
        }
        .onChange(of: appModel.bestCorrectStreak) {
            prevBestCorrectStreak = appModel.bestCorrectStreak
        }
    }
    
    // MARK: - Main Scroll View
    
    private var mainScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                // REMOVED: streakPillsSection (was duplicate)
                // Stats bar alone is sufficient
                
                quoteCardSection
                
                quickStatsBar
                    .padding(.top, 16)
                    .opacity(statsAppeared ? 1 : 0)
                    .offset(y: statsAppeared ? 0 : 15)
                
                ctaSection
                    .padding(.top, 24)
                    .opacity(ctaAppeared ? 1 : 0)
                    .scaleEffect(ctaAppeared ? 1 : 0.95)
                
                if !entitlements.isPlus {
                    premiumTeaser
                        .padding(.top, 24)
                }
                
                achievementsCard
                    .padding(.top, 24)
                    .padding(.bottom, 32)
            }
        }
    }
    
    private var quoteCardSection: some View {
        QuoteCard(
            text: appModel.todayQuote.text,
            movie: appModel.todayQuote.movie,
            year: appModel.todayQuote.year
        )
        .opacity(quoteAppeared ? 1 : 0)
        .offset(y: quoteAppeared ? 0 : 20)
        .padding(.top, 20)
    }
    
    // MARK: - Achievements Card
    
    private var achievementsCard: some View {
        Button {
            showAllAchievements = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("View Achievements")
                        .font(.subheadline.weight(.semibold))
                    
                    Text("Track streaks, XP, and more")
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
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Toast Overlay
    
    @ViewBuilder
    private var toastOverlay: some View {
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
    
    private func handleOnAppear() {
        appModel.refreshDailyStateIfNeeded()
        handleCorrectStreakChange(appModel.correctStreak)
        prevBestCorrectStreak = appModel.bestCorrectStreak
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            quoteAppeared = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25)) {
            statsAppeared = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
            ctaAppeared = true
        }
        
        if !appModel.quizCompletedToday {
            startPulseAnimation()
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
    
    // MARK: - Quick Stats Bar (Single source of streak info)
    
    private var quickStatsBar: some View {
        HStack(spacing: 0) {
            quickStatItem(
                icon: "calendar",
                label: "Day Streak",
                value: "\(appModel.dailyStreak)",
                color: streakAtRisk ? .orange : .secondary
            )
            
            Divider()
                .frame(height: 28)
                .opacity(0.3)
            
            quickStatItem(
                icon: "flame.fill",
                label: "Correct",
                value: "\(appModel.correctStreak)",
                color: appModel.correctStreak > 0 ? .orange : .secondary
            )
            
            Divider()
                .frame(height: 28)
                .opacity(0.3)
            
            quickStatItem(
                icon: "trophy.fill",
                label: "Best",
                value: "\(appModel.bestCorrectStreak)",
                color: .yellow
            )
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    private func quickStatItem(icon: String, label: String, value: String, color: Color = .secondary) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .imageScale(.small)
                .foregroundStyle(color)
            
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
    
    @ViewBuilder
    private var ctaSection: some View {
        if !appModel.quizCompletedToday {
            ctaNotCompletedSection
        } else {
            ctaCompletedSection
        }
    }
    
    private var ctaNotCompletedSection: some View {
        VStack(spacing: 0) {
            quizButton
            
            if streakAtRisk {
                streakRiskWarning
            }
        }
    }
    
    private var quizButton: some View {
        Button {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            onStartQuiz?()
        } label: {
            ctaButtonLabel
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .accessibilityIdentifier("startQuizButton")
    }
    
    private var ctaButtonLabel: some View {
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
        .background(ctaButtonBackground)
        .foregroundStyle(.white)
        .shadow(color: .orange.opacity(0.4), radius: 12, y: 6)
        .scaleEffect(pulseQuizButton ? 1.02 : 1.0)
    }
    
    private var ctaButtonBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color.orange, Color.red.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
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
    }
    
    private var streakRiskWarning: some View {
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
    
    private var ctaCompletedSection: some View {
        VStack(spacing: 12) {
            completedBanner
            endlessModeButton
        }
        .padding(.horizontal, 20)
    }
    
    private var completedBanner: some View {
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
    }
    
    // IMPROVED: More compelling "Play More Trivia" button
    private var endlessModeButton: some View {
        Button {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            onStartEndlessTrivia?()
        } label: {
            HStack(spacing: 12) {
                // Icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "infinity")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Endless Trivia")
                        .font(.headline.weight(.bold))
                    
                    Text("Keep the movie magic going")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.purple)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.purple.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Premium Teaser (FIXED: Now actually opens paywall!)
    
    private var premiumTeaser: some View {
        Button {
            showPaywall = true  // FIXED: Was empty before!
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
                    Text("Unlock FilmFuel Plus")
                        .font(.subheadline.weight(.bold))
                    
                    // Personalized based on usage
                    if appModel.correctStreak > 0 {
                        Text("Keep your \(appModel.correctStreak)-streak going strong")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Unlimited trivia • Smart discovery • No ads")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text("Try Free")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.2))
                    )
                    .foregroundStyle(.orange)
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

// MARK: - Quote Card

private struct QuoteCard: View {
    let text: String
    let movie: String
    let year: Int
    
    var body: some View {
        VStack(spacing: 20) {
            Text("\"\(text)\"")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .lineLimit(6)
                .minimumScaleFactor(0.8)

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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
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
    }
}
