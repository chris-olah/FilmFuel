//
//  AchievementsView.swift
//  FilmFuel
//
//  UPDATED: Better unlock animations, clearer progress indicators,
//  improved card design, haptic feedback
//

import SwiftUI

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(
                .spring(response: 0.25, dampingFraction: 0.8),
                value: configuration.isPressed
            )
    }
}

// MARK: - Achievements View

struct AchievementsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var entitlements: FilmFuelEntitlements
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: AchievementCategory? = nil
    @State private var showUnlockedOnly: Bool = false
    @State private var animateHeader: Bool = false
    @State private var selectedAchievement: AchievementDefinition? = nil
    @State private var showPaywall: Bool = false
    
    // Computed properties
    private var filteredAchievements: [AchievementDefinition] {
        var achievements = AchievementDefinition.all
        
        // Filter by category
        if let category = selectedCategory {
            achievements = achievements.filter { $0.category == category }
        }
        
        // Filter locked/unlocked
        if showUnlockedOnly {
            achievements = achievements.filter { AchievementDefinition.isUnlocked($0.id) }
        }
        
        // Hide secret achievements that aren't unlocked
        achievements = achievements.filter {
            !$0.isSecret || AchievementDefinition.isUnlocked($0.id)
        }
        
        return achievements
    }
    
    private var unlockedCount: Int {
        AchievementDefinition.unlockedAchievements().count
    }
    
    private var totalCount: Int {
        AchievementDefinition.all.filter { !$0.isSecret || AchievementDefinition.isUnlocked($0.id) }.count
    }
    
    private var totalXP: Int {
        AchievementDefinition.totalXPFromAchievements
    }
    
    // NEW: Achievements close to unlocking
    private var nearlyUnlockedCount: Int {
        AchievementDefinition.all.filter { achievement in
            !AchievementDefinition.isUnlocked(achievement.id) &&
            AchievementDefinition.progress(for: achievement) >= 0.7
        }.count
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Hero Header
                headerSection
                
                // Category Pills
                categoryPillsSection
                    .padding(.top, 16)
                
                // Filter Toggle
                filterToggle
                    .padding(.top, 12)
                
                // Near completion hint
                if nearlyUnlockedCount > 0 && !showUnlockedOnly {
                    nearCompletionHint
                        .padding(.top, 12)
                }
                
                // Achievements Grid
                achievementsGrid
                    .padding(.top, 20)
                    .padding(.bottom, 32)
            }
        }
        .background(
            AchievementsBackground()
                .ignoresSafeArea()
        )
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(item: $selectedAchievement) { achievement in
            AchievementDetailSheet(achievement: achievement)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPaywall) {
            FilmFuelPlusPaywallView()
                .environmentObject(entitlements)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animateHeader = true
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Trophy Icon with glow
            headerTrophyIcon
                .padding(.top, 20)
            
            // Stats
            headerStats
            
            // Progress Bar
            headerProgressBar
        }
        .padding(.bottom, 8)
    }
    
    private var headerTrophyIcon: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.yellow.opacity(0.4), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .blur(radius: 20)
                .opacity(animateHeader ? 1 : 0)
            
            // Trophy
            Image(systemName: "trophy.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .yellow.opacity(0.5), radius: 10, y: 5)
                .scaleEffect(animateHeader ? 1 : 0.5)
                .opacity(animateHeader ? 1 : 0)
        }
    }
    
    private var headerStats: some View {
        VStack(spacing: 8) {
            Text("\(unlockedCount) / \(totalCount)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, .primary.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Achievements Unlocked")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .opacity(animateHeader ? 1 : 0)
        .offset(y: animateHeader ? 0 : 20)
    }
    
    private var headerProgressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: animateHeader
                                ? geo.size.width * CGFloat(AchievementDefinition.completionPercentage / 100)
                                : 0,
                            height: 12
                        )
                        .animation(
                            .spring(response: 1.0, dampingFraction: 0.8).delay(0.5),
                            value: animateHeader
                        )
                }
            }
            .frame(height: 12)
            
            progressLabels
        }
        .padding(.horizontal, 24)
        .opacity(animateHeader ? 1 : 0)
    }
    
    private var progressLabels: some View {
        HStack {
            Text("\(Int(AchievementDefinition.completionPercentage))% Complete")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .imageScale(.small)
                Text("\(totalXP) XP")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
        }
    }
    
    // MARK: - Near Completion Hint
    
    private var nearCompletionHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .foregroundColor(.orange)
            
            Text("\(nearlyUnlockedCount) achievement\(nearlyUnlockedCount == 1 ? "" : "s") almost unlocked!")
                .font(.caption.weight(.medium))
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .imageScale(.small)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
        .padding(.horizontal)
    }
    
    // MARK: - Category Pills
    
    private var categoryPillsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // All category
                CategoryPill(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    color: .accentColor
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedCategory = nil
                    }
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                }
                
                // Category pills
                ForEach(AchievementCategory.allCases, id: \.self) { category in
                    CategoryPill(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category,
                        color: category.color
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedCategory = category
                        }
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Filter Toggle
    
    private var filterToggle: some View {
        HStack {
            Text("Show unlocked only")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Toggle("", isOn: $showUnlockedOnly)
                .labelsHidden()
                .tint(.orange)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Achievements Grid
    
    private var achievementsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(filteredAchievements) { achievement in
                AchievementCard(achievement: achievement)
                    .onTapGesture {
                        selectedAchievement = achievement
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                    }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Category Pill

private struct CategoryPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .imageScale(.small)
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.15) : Color(.secondarySystemBackground))
            )
            .foregroundStyle(isSelected ? color : .primary)
            .overlay(
                Capsule()
                    .stroke(isSelected ? color.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Achievement Card (IMPROVED)

private struct AchievementCard: View {
    let achievement: AchievementDefinition
    
    private var isUnlocked: Bool {
        AchievementDefinition.isUnlocked(achievement.id)
    }
    
    private var progress: Double {
        AchievementDefinition.progress(for: achievement)
    }
    
    // NEW: Check if nearly complete
    private var isNearlyComplete: Bool {
        !isUnlocked && progress >= 0.7
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon with progress ring
            iconSection
            
            // Title and description
            textSection
            
            // XP reward
            xpRewardSection
            
            // Rarity badge
            rarityBadge
        }
        .padding(16)
        .background(cardBackground)
        .overlay(cardOverlay)
        .opacity(isUnlocked ? 1.0 : 0.7)
    }
    
    // MARK: - Icon with Progress Ring
    
    private var iconSection: some View {
        ZStack {
            // Progress ring for locked achievements
            if !isUnlocked {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 3)
                    .frame(width: 56, height: 56)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        achievement.category.color,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
            }
            
            // Icon background
            Circle()
                .fill(
                    isUnlocked
                        ? achievement.rarity.color.opacity(0.15)
                        : Color(.systemGray5)
                )
                .frame(width: 48, height: 48)
            
            // Icon
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundStyle(
                    isUnlocked ? achievement.rarity.color : .secondary
                )
            
            // Checkmark for unlocked
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .background(Circle().fill(Color(.systemBackground)).padding(-2))
                    .offset(x: 18, y: 18)
            }
            
            // "Almost there" indicator
            if isNearlyComplete {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .background(Circle().fill(Color(.systemBackground)).padding(-2))
                    .offset(x: 18, y: -18)
            }
        }
    }
    
    // MARK: - Text Section
    
    private var textSection: some View {
        VStack(spacing: 4) {
            Text(achievement.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            
            Text(achievement.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - XP Reward
    
    private var xpRewardSection: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .imageScale(.small)
            Text(isUnlocked ? "Earned" : "+\(achievement.xpReward) XP")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(isUnlocked ? .green : .orange.opacity(0.8))
    }
    
    // MARK: - Rarity Badge
    
    private var rarityBadge: some View {
        Text(achievement.rarity.rawValue)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(achievement.rarity.color.opacity(0.15))
            )
            .foregroundStyle(achievement.rarity.color)
    }
    
    // MARK: - Card Background & Overlay
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .shadow(
                color: isUnlocked ? achievement.rarity.glowColor : .clear,
                radius: 12,
                y: 4
            )
    }
    
    private var cardOverlay: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(
                isUnlocked
                    ? achievement.rarity.color.opacity(0.3)
                    : isNearlyComplete ? Color.orange.opacity(0.3) : .clear,
                lineWidth: 1
            )
    }
}

// MARK: - Achievement Detail Sheet

private struct AchievementDetailSheet: View {
    let achievement: AchievementDefinition
    @Environment(\.dismiss) private var dismiss
    
    private var isUnlocked: Bool {
        AchievementDefinition.isUnlocked(achievement.id)
    }
    
    private var progress: Double {
        AchievementDefinition.progress(for: achievement)
    }
    
    private var currentValue: Int {
        AchievementDefinition.currentValue(for: achievement)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            detailIcon
            detailTitleSection
            
            if !isUnlocked {
                detailProgressSection
            }
            
            detailStatsSection
            
            if isUnlocked, let date = AchievementDefinition.unlockDate(for: achievement.id) {
                unlockDateSection(date: date)
            }
            
            Spacer()
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }
    
    private var detailIcon: some View {
        ZStack {
            // Glow for unlocked
            if isUnlocked {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [achievement.rarity.color.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 15)
            }
            
            Circle()
                .fill(
                    isUnlocked
                        ? achievement.rarity.color.opacity(0.15)
                        : Color(.systemGray5)
                )
                .frame(width: 80, height: 80)
            
            Image(systemName: achievement.icon)
                .font(.system(size: 36))
                .foregroundStyle(
                    isUnlocked ? achievement.rarity.color : .secondary
                )
        }
    }
    
    private var detailTitleSection: some View {
        VStack(spacing: 8) {
            Text(achievement.title)
                .font(.title2.weight(.bold))
            
            Text(achievement.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var detailProgressSection: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
                .tint(achievement.category.color)
            
            Text("\(currentValue) / \(achievement.requirement)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 40)
    }
    
    private var detailStatsSection: some View {
        HStack(spacing: 24) {
            statItem(
                value: achievement.rarity.rawValue,
                label: "Rarity",
                color: achievement.rarity.color
            )
            
            Divider()
                .frame(height: 30)
            
            statItem(
                value: "+\(achievement.xpReward)",
                label: "XP Reward",
                color: .green
            )
            
            Divider()
                .frame(height: 30)
            
            statItem(
                value: achievement.category.rawValue,
                label: "Category",
                color: achievement.category.color
            )
        }
    }
    
    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
    
    private func unlockDateSection(date: Date) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
            Text("Unlocked \(date.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Animated Background

private struct AchievementsBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
            
            // Subtle gradient orbs
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.yellow.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 50,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: animate ? -50 : -100, y: animate ? -100 : -150)
                .blur(radius: 50)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.orange.opacity(0.06), .clear],
                        center: .center,
                        startRadius: 50,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: animate ? 100 : 150, y: animate ? 300 : 350)
                .blur(radius: 40)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 8)
                .repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AchievementsView()
            .environmentObject(AppModel())
            .environmentObject(FilmFuelEntitlements())
    }
}
