//
//  AchievementsView.swift
//  FilmFuel
//
//  A premium achievements gallery with immersive animations,
//  category filtering, progress tracking, and reward celebration.
//

import SwiftUI

// MARK: - Pressable Button Style (for nice tap feedback without breaking scroll)

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
    
    // MARK: - Category Pills
    
    private var categoryPillsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // All category
                CategoryPill(
                    title: "All",
                    icon: "square.grid.2x2.fill",
                    color: .gray,
                    isSelected: selectedCategory == nil,
                    count: AchievementDefinition.all.filter {
                        !$0.isSecret || AchievementDefinition.isUnlocked($0.id)
                    }.count
                ) {
                    withAnimation(.spring(response: 0.35)) {
                        selectedCategory = nil
                    }
                }
                
                ForEach(AchievementCategory.allCases) { category in
                    let achievements = AchievementDefinition.achievements(for: category)
                    let visibleCount = achievements.filter {
                        !$0.isSecret || AchievementDefinition.isUnlocked($0.id)
                    }.count
                    
                    CategoryPill(
                        title: category.rawValue,
                        icon: category.icon,
                        color: category.color,
                        isSelected: selectedCategory == category,
                        count: visibleCount
                    ) {
                        withAnimation(.spring(response: 0.35)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Filter Toggle
    
    private var filterToggle: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showUnlockedOnly.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showUnlockedOnly ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(showUnlockedOnly ? .green : .secondary)
                    
                    Text("Show unlocked only")
                        .font(.subheadline)
                        .foregroundStyle(showUnlockedOnly ? .primary : .secondary)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("\(filteredAchievements.count) achievements")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
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
                AchievementCard(
                    achievement: achievement,
                    isUnlocked: AchievementDefinition.isUnlocked(achievement.id),
                    progress: AchievementDefinition.progress(for: achievement),
                    isPremiumUser: entitlements.isPlus
                ) {
                    if achievement.isPremium && !entitlements.isPlus {
                        showPaywall = true
                    } else {
                        selectedAchievement = achievement
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Category Pill

private struct CategoryPill: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            pillContent
        }
        .buttonStyle(PressableButtonStyle(scale: 0.97))
    }
    
    private var pillContent: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .imageScale(.small)
            
            Text(title)
                .font(.subheadline.weight(.medium))
            
            countBadge
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(pillBackground)
        .foregroundStyle(isSelected ? .white : .primary)
        .overlay(pillOverlay)
    }
    
    private var countBadge: some View {
        Text("\(count)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(isSelected ? .white.opacity(0.2) : Color(.systemGray5))
            )
    }
    
    private var pillBackground: some View {
        Capsule()
            .fill(isSelected ? color : Color(.secondarySystemBackground))
    }
    
    private var pillOverlay: some View {
        Capsule()
            .stroke(isSelected ? color.opacity(0.5) : .clear, lineWidth: 1)
    }
}

// MARK: - Achievement Card

private struct AchievementCard: View {
    let achievement: AchievementDefinition
    let isUnlocked: Bool
    let progress: Double
    let isPremiumUser: Bool
    let action: () -> Void
    
    private var isLocked: Bool {
        achievement.isPremium && !isPremiumUser && !isUnlocked
    }
    
    var body: some View {
        Button(action: action) {
            cardContent
        }
        .buttonStyle(PressableButtonStyle())
    }
    
    private var cardContent: some View {
        VStack(spacing: 12) {
            iconSection
            titleSection
            xpRewardSection
            rarityBadge
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .overlay(cardOverlay)
    }
    
    // MARK: - Icon Section
    
    private var iconSection: some View {
        ZStack {
            progressRing
            iconCircle
            unlockedCheckmark
            premiumBadge
        }
    }
    
    private var progressRing: some View {
        ZStack {
            // Progress ring background
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 4)
                .frame(width: 64, height: 64)
            
            // Progress ring fill
            Circle()
                .trim(from: 0, to: isUnlocked ? 1.0 : progress)
                .stroke(
                    isUnlocked ? achievement.rarity.color : achievement.category.color,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 64, height: 64)
                .rotationEffect(.degrees(-90))
        }
    }
    
    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(
                    isUnlocked
                        ? achievement.rarity.color.opacity(0.15)
                        : Color(.systemGray6)
                )
                .frame(width: 52, height: 52)
            
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundStyle(
                        isUnlocked
                            ? achievement.rarity.color
                            : .secondary
                    )
            }
        }
    }
    
    @ViewBuilder
    private var unlockedCheckmark: some View {
        if isUnlocked {
            Circle()
                .fill(.green)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                )
                .offset(x: 24, y: -24)
        }
    }
    
    @ViewBuilder
    private var premiumBadge: some View {
        if achievement.isPremium && !isUnlocked {
            Image(systemName: "crown.fill")
                .font(.caption2)
                .foregroundStyle(.yellow)
                .padding(4)
                .background(Circle().fill(Color(.systemBackground)))
                .offset(x: -24, y: -24)
        }
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(spacing: 4) {
            Text(achievement.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(isLocked ? .secondary : .primary)
            
            Text(achievement.description)
                .font(.caption2)
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
            Text("+\(achievement.xpReward) XP")
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
                    : .clear,
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
