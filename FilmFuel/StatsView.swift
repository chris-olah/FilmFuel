//
//  StatsView.swift
//  FilmFuel
//
//  UPDATED: Better level display, cleaner cards, improved animations
//

import SwiftUI

struct StatsView: View {
    private let stats = StatsManager.shared
    @EnvironmentObject var entitlements: FilmFuelEntitlements
    
    @State private var showingAchievements = false
    @State private var animateProgress = false
    
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }
    
    // Computed stats
    private var userLevel: UserLevel {
        UserLevel.level(for: totalXP)
    }
    
    private var totalXP: Int {
        let triviaXP = stats.totalTriviaCorrect * 5
        let discoveryXP = stats.discoverCardsViewed * 1
        let engagementXP = stats.uniqueDaysUsed * 10
        let streakXP = currentStreak * 5
        return triviaXP + discoveryXP + engagementXP + streakXP
    }
    
    private var currentStreak: Int {
        UserDefaults.standard.integer(forKey: "ff.engagement.streak")
    }
    
    private var longestStreak: Int {
        UserDefaults.standard.integer(forKey: "ff.engagement.longestStreak")
    }
    
    private var levelProgress: Double {
        guard let next = userLevel.next else { return 1.0 }
        let current = userLevel.requiredXP
        let needed = next.requiredXP - current
        let progress = totalXP - current
        return min(1.0, Double(progress) / Double(needed))
    }
    
    private var xpToNextLevel: Int {
        guard let next = userLevel.next else { return 0 }
        return max(0, next.requiredXP - totalXP)
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Hero card with level
                    levelHeroCard
                    
                    // Streak card
                    streakCard
                    
                    // Quick stats grid
                    quickStatsGrid
                    
                    // Detailed sections
                    detailedStatsList
                    
                    // Achievements teaser
                    achievementsTeaser
                }
                .padding()
            }
        }
        .navigationTitle("Your Stats")
        .sheet(isPresented: $showingAchievements) {
            AchievementsFullView()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateProgress = true
            }
        }
    }
    
    // MARK: - Level Hero Card
    
    private var levelHeroCard: some View {
        VStack(spacing: 16) {
            // Level badge with glow
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.accentColor.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 15)
                    .opacity(animateProgress ? 1 : 0)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: userLevel.icon)
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
            }
            .scaleEffect(animateProgress ? 1 : 0.8)
            .opacity(animateProgress ? 1 : 0)
            
            VStack(spacing: 4) {
                Text(userLevel.title)
                    .font(.title2.weight(.bold))
                
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                    Text("\(totalXP) XP")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            // Progress to next level
            if let next = userLevel.next {
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.tertiarySystemFill))
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [.accentColor, .accentColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: animateProgress ? geo.size.width * levelProgress : 0)
                        }
                    }
                    .frame(height: 10)
                    
                    HStack {
                        Text("\(xpToNextLevel) XP to \(next.title)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(levelProgress * 100))%")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.accentColor)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("Maximum level reached!")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Streak Card
    
    private var streakCard: some View {
        HStack(spacing: 20) {
            // Current streak
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(currentStreak >= 7 ? .orange : .secondary)
                    Text("\(currentStreak)")
                        .font(.title.weight(.bold))
                }
                Text("Current streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 40)
            
            // Longest streak
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("\(longestStreak)")
                        .font(.title.weight(.bold))
                }
                Text("Longest streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Quick Stats Grid
    
    private var quickStatsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            QuickStatCard(
                icon: "eye.fill",
                value: "\(stats.discoverCardsViewed)",
                label: "Movies Explored",
                color: .blue
            )
            
            QuickStatCard(
                icon: "checkmark.circle.fill",
                value: "\(stats.totalTriviaCorrect)",
                label: "Trivia Correct",
                color: .green
            )
            
            QuickStatCard(
                icon: "target",
                value: "\(stats.triviaAccuracy)%",
                label: "Accuracy",
                color: .orange
            )
            
            QuickStatCard(
                icon: "calendar",
                value: "\(stats.uniqueDaysUsed)",
                label: "Days Active",
                color: .purple
            )
        }
    }
    
    // MARK: - Detailed Stats List
    
    private var detailedStatsList: some View {
        VStack(spacing: 16) {
            // Trivia stats
            StatSection(title: "Trivia", icon: "brain.fill") {
                StatRow(icon: "questionmark.circle", title: "Total Answered", value: "\(stats.totalTriviaAnswered)")
                StatRow(icon: "checkmark.circle", title: "Correct Answers", value: "\(stats.totalTriviaCorrect)")
                StatRow(icon: "percent", title: "Accuracy Rate", value: "\(stats.triviaAccuracy)%")
            }
            
            // Discovery stats
            StatSection(title: "Discovery", icon: "sparkles") {
                StatRow(icon: "eye", title: "Movies Viewed", value: "\(stats.discoverCardsViewed)")
                // Placeholder for favorites until StatsManager supports it
                StatRow(icon: "heart.fill", title: "Favorites", value: "—")
                StatRow(icon: "bookmark.fill", title: "Watchlist", value: "\(stats.watchlistCount)")
            }
            
            // Engagement stats
            StatSection(title: "Engagement", icon: "chart.line.uptrend.xyaxis") {
                StatRow(icon: "calendar", title: "Days Used", value: "\(stats.uniqueDaysUsed)")
                StatRow(icon: "flame", title: "Current Streak", value: "\(currentStreak) days")
                StatRow(icon: "trophy", title: "Best Streak", value: "\(longestStreak) days")
            }
        }
    }
    
    // MARK: - Achievements Teaser
    
    private var achievementsTeaser: some View {
        Button {
            showingAchievements = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "trophy.fill")
                        .font(.title3)
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("View Achievements")
                        .font(.headline)
                    
                    Text("Track your progress and unlock rewards")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Stat Card

private struct QuickStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2.weight(.bold))
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Stat Section

private struct StatSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }
            
            VStack(spacing: 8) {
                content()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

// MARK: - Stat Row

private struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .imageScale(.medium)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Achievements Full View

struct AchievementsFullView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Sample achievements
    private let achievements: [AchievementItem] = [
        AchievementItem(id: "first_trivia", title: "Quiz Starter", description: "Complete your first trivia", icon: "star.fill", xp: 10, isUnlocked: true),
        AchievementItem(id: "streak_3", title: "Getting Hooked", description: "3-day streak", icon: "flame.fill", xp: 30, isUnlocked: true),
        AchievementItem(id: "streak_7", title: "Week Warrior", description: "7-day streak", icon: "flame.fill", xp: 75, isUnlocked: false),
        AchievementItem(id: "trivia_50", title: "Trivia Master", description: "Answer 50 questions correctly", icon: "brain.fill", xp: 50, isUnlocked: false),
        AchievementItem(id: "explorer_100", title: "Movie Explorer", description: "View 100 movies", icon: "binoculars.fill", xp: 40, isUnlocked: false),
        AchievementItem(id: "perfect_round", title: "Perfect Round", description: "Get all questions right in a session", icon: "crown.fill", xp: 100, isUnlocked: false),
        AchievementItem(id: "streak_30", title: "Monthly Master", description: "30-day streak", icon: "trophy.fill", xp: 300, isUnlocked: false),
        AchievementItem(id: "trivia_500", title: "Trivia Legend", description: "Answer 500 questions correctly", icon: "star.circle.fill", xp: 500, isUnlocked: false),
    ]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    let unlocked = achievements.filter { $0.isUnlocked }.count
                    let total = achievements.count
                    
                    VStack(spacing: 8) {
                        Text("\(unlocked)/\(total)")
                            .font(.largeTitle.weight(.bold))
                        Text("Achievements Unlocked")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ProgressView(value: Double(unlocked), total: Double(total))
                            .tint(.accentColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                Section("Unlocked") {
                    ForEach(achievements.filter { $0.isUnlocked }) { achievement in
                        AchievementRow(achievement: achievement)
                    }
                }
                
                Section("Locked") {
                    ForEach(achievements.filter { !$0.isUnlocked }) { achievement in
                        AchievementRow(achievement: achievement)
                    }
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct AchievementItem: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let xp: Int
    let isUnlocked: Bool
}

private struct AchievementRow: View {
    let achievement: AchievementItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundColor(achievement.isUnlocked ? .accentColor : .secondary)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Text("+\(achievement.xp) XP")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
        .opacity(achievement.isUnlocked ? 1.0 : 0.6)
    }
}

#Preview {
    NavigationStack {
        StatsView()
            .environmentObject(FilmFuelEntitlements())
    }
}
