//
//  AchievementUI.swift
//  FilmFuel
//
//  Created by Chris Olah on 11/30/25.
//

//
//  AchievementUI.swift
//  FilmFuel
//
//  Shared achievement UI components used across HomeView and AchievementsView.
//

import SwiftUI

// MARK: - Achievement Badge

struct AchievementBadge: View {
    let icon: String
    let title: String
    let subtitle: String
    let progress: Double
    let isUnlocked: Bool
    var rarity: AchievementRarity = .common
    var isPremium: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            badgeIcon
            badgeLabels
        }
        .frame(width: 90)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(badgeBackground)
        .overlay(badgeOverlay)
    }
    
    // MARK: - Icon
    
    private var badgeIcon: some View {
        ZStack {
            progressRing
            iconView
            lockOverlay
            checkmarkOverlay
        }
    }
    
    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                .frame(width: 56, height: 56)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isUnlocked ? rarity.color : Color.orange,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(-90))
        }
    }
    
    private var iconView: some View {
        Image(systemName: icon)
            .font(.title3)
            .foregroundStyle(isUnlocked ? rarity.color : .secondary)
    }
    
    @ViewBuilder
    private var lockOverlay: some View {
        if isPremium && !isUnlocked {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 56, height: 56)
            
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private var checkmarkOverlay: some View {
        if isUnlocked {
            Circle()
                .fill(.green)
                .frame(width: 16, height: 16)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                )
                .offset(x: 20, y: -20)
        }
    }
    
    // MARK: - Labels
    
    private var badgeLabels: some View {
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
    
    // MARK: - Background / Overlay
    
    private var badgeBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isUnlocked ? rarity.color.opacity(0.1) : Color(.secondarySystemBackground))
    }
    
    private var badgeOverlay: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(isUnlocked ? rarity.color.opacity(0.3) : .clear, lineWidth: 1)
    }
}

// MARK: - Progress Bar View

struct ProgressBarView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                backgroundBar
                foregroundBar(width: geo.size.width * progress)
            }
        }
        .frame(height: 6)
    }
    
    private var backgroundBar: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(.systemGray5))
            .frame(height: 6)
    }
    
    private func foregroundBar(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: max(0, width), height: 6)
    }
}

// MARK: - Near Complete Section

struct NearCompleteSection: View {
    let achievements: [AchievementDefinition]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader
            
            ForEach(achievements, id: \.id) { achievement in
                NearCompleteRow(achievement: achievement)
            }
        }
        .padding(12)
        .background(sectionBackground)
    }
    
    private var sectionHeader: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkle")
                .foregroundStyle(.orange)
                .imageScale(.small)
            Text("Almost there!")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
    
    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.orange.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Near Complete Row

struct NearCompleteRow: View {
    let achievement: AchievementDefinition
    
    private var progress: Double {
        AchievementDefinition.progress(for: achievement)
    }
    
    private var current: Int {
        AchievementDefinition.currentValue(for: achievement)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            achievementIcon
            progressSection
            progressLabel
        }
    }
    
    private var achievementIcon: some View {
        Image(systemName: achievement.icon)
            .font(.subheadline)
            .foregroundStyle(achievement.category.color)
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(achievement.category.color.opacity(0.15))
            )
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(achievement.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            
            ProgressBarView(progress: progress, color: achievement.category.color)
        }
    }
    
    private var progressLabel: some View {
        Text("\(current)/\(achievement.requirement)")
            .font(.caption2.weight(.medium).monospacedDigit())
            .foregroundStyle(.secondary)
    }
}

// MARK: - More Achievements Card

struct MoreAchievementsCard: View {
    let action: () -> Void
    
    private var lockedCount: Int {
        AchievementDefinition.lockedAchievements().count
    }
    
    var body: some View {
        Button(action: action) {
            cardContent
        }
        .buttonStyle(.plain)
    }
    
    private var cardContent: some View {
        VStack(spacing: 8) {
            iconCircle
            labels
        }
        .frame(width: 90)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(cardBackground)
    }
    
    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange.opacity(0.2), .yellow.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
            
            Image(systemName: "ellipsis")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.orange)
        }
    }
    
    private var labels: some View {
        VStack(spacing: 2) {
            Text("View All")
                .font(.caption.weight(.semibold))
            
            Text("\(lockedCount) more")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.orange.opacity(0.3), .yellow.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        AchievementBadge(
            icon: "flame.fill",
            title: "Week Warrior",
            subtitle: "Maintain a 7-day streak",
            progress: 0.7,
            isUnlocked: false,
            rarity: .uncommon,
            isPremium: false
        )
        
        NearCompleteSection(
            achievements: Array(AchievementDefinition.all.prefix(2))
        )
        
        MoreAchievementsCard {
            print("Tapped More")
        }
    }
    .padding()
}
