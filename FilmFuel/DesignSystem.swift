//
//  DesignSystem.swift
//  FilmFuel
//
//  Centralized design tokens for consistency across the app
//

import SwiftUI

// MARK: - Spacing

enum FFSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

// MARK: - Corner Radius

enum FFRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 20
    static let card: CGFloat = 24
}

// MARK: - Colors

extension Color {
    // Brand
    static let ffAccent = Color.orange
    static let ffPremium = Color.yellow
    
    // Semantic
    static let ffSuccess = Color.green
    static let ffWarning = Color.orange
    static let ffError = Color.red
    static let ffStreak = Color.orange
    
    // Gradients
    static var ffPrimaryGradient: LinearGradient {
        LinearGradient(
            colors: [.orange, .red.opacity(0.9)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var ffPremiumGradient: LinearGradient {
        LinearGradient(
            colors: [.yellow, .orange],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    static var ffSubtleGradient: LinearGradient {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    static var ffPurpleGradient: LinearGradient {
        LinearGradient(
            colors: [.purple, .indigo],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Typography

extension Font {
    // Display
    static let ffLargeTitle = Font.largeTitle.weight(.bold)
    static let ffTitle = Font.title.weight(.bold)
    static let ffTitle2 = Font.title2.weight(.bold)
    static let ffTitle3 = Font.title3.weight(.semibold)
    
    // Body
    static let ffHeadline = Font.headline.weight(.semibold)
    static let ffBody = Font.body
    static let ffCallout = Font.callout
    
    // Small
    static let ffCaption = Font.caption.weight(.medium)
    static let ffCaption2 = Font.caption2.weight(.medium)
    
    // Metrics (for numbers, stats)
    static let ffMetric = Font.system(.title2, design: .rounded).weight(.bold)
    static let ffMetricSmall = Font.system(.headline, design: .rounded).weight(.bold)
}

// MARK: - Card Modifier

struct FFCardModifier: ViewModifier {
    var style: CardStyle = .elevated
    
    enum CardStyle {
        case elevated
        case glass
        case outlined
        case premium
    }
    
    func body(content: Content) -> some View {
        content
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: FFRadius.card, style: .continuous))
            .overlay(overlay)
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
    }
    
    @ViewBuilder
    private var background: some View {
        switch style {
        case .elevated:
            Color(.secondarySystemBackground)
        case .glass:
            Rectangle().fill(.ultraThinMaterial)
        case .outlined:
            Color.clear
        case .premium:
            LinearGradient(
                colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    @ViewBuilder
    private var overlay: some View {
        switch style {
        case .outlined:
            RoundedRectangle(cornerRadius: FFRadius.card, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        case .premium:
            RoundedRectangle(cornerRadius: FFRadius.card, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.yellow.opacity(0.5), .orange.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        default:
            EmptyView()
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .elevated: return .black.opacity(0.08)
        case .premium: return .orange.opacity(0.1)
        default: return .clear
        }
    }
    
    private var shadowRadius: CGFloat {
        switch style {
        case .elevated, .premium: return 12
        default: return 0
        }
    }
    
    private var shadowY: CGFloat {
        switch style {
        case .elevated, .premium: return 6
        default: return 0
        }
    }
}

extension View {
    func ffCard(_ style: FFCardModifier.CardStyle = .elevated) -> some View {
        modifier(FFCardModifier(style: style))
    }
}

// MARK: - Button Styles

struct FFPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isEnabled
                        ? [Color.orange, Color.red.opacity(0.9)]
                        : [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: FFRadius.large, style: .continuous))
            .shadow(
                color: isEnabled ? Color.orange.opacity(0.4) : .clear,
                radius: 12,
                y: 6
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct FFSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: FFRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FFRadius.medium, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct FFPremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.yellow, Color.orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: FFRadius.large, style: .continuous))
            .shadow(color: Color.yellow.opacity(0.4), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FFPrimaryButtonStyle {
    static var ffPrimary: FFPrimaryButtonStyle { FFPrimaryButtonStyle() }
}

extension ButtonStyle where Self == FFSecondaryButtonStyle {
    static var ffSecondary: FFSecondaryButtonStyle { FFSecondaryButtonStyle() }
}

extension ButtonStyle where Self == FFPremiumButtonStyle {
    static var ffPremium: FFPremiumButtonStyle { FFPremiumButtonStyle() }
}

// MARK: - Pressable Button Style (for cards that act as buttons)

struct FFPressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(
                .spring(response: 0.25, dampingFraction: 0.8),
                value: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == FFPressableButtonStyle {
    static var ffPressable: FFPressableButtonStyle { FFPressableButtonStyle() }
}

// MARK: - Stat Display Component

struct FFStatDisplay: View {
    let value: String
    let label: String
    let icon: String?
    var color: Color = .primary
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(color)
                }
                Text(value)
                    .font(.ffMetricSmall)
            }
            Text(label)
                .font(.ffCaption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Badge Component

struct FFBadge: View {
    let text: String
    var color: Color = .accentColor
    var size: BadgeSize = .medium
    
    enum BadgeSize {
        case small, medium
        
        var font: Font {
            switch self {
            case .small: return .system(size: 9, weight: .bold)
            case .medium: return .caption2.weight(.bold)
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
            case .medium: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            }
        }
    }
    
    var body: some View {
        Text(text)
            .font(size.font)
            .padding(size.padding)
            .background(color)
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}

// MARK: - Progress Ring

struct FFProgressRing: View {
    let progress: Double
    var color: Color = .accentColor
    var lineWidth: CGFloat = 4
    var size: CGFloat = 44
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview("Design System") {
    ScrollView {
        VStack(spacing: 24) {
            // Cards
            Group {
                Text("Elevated Card")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .ffCard(.elevated)
                
                Text("Glass Card")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .ffCard(.glass)
                
                Text("Premium Card")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .ffCard(.premium)
            }
            
            // Buttons
            Group {
                Button("Primary Button") {}
                    .buttonStyle(.ffPrimary)
                
                Button("Secondary Button") {}
                    .buttonStyle(.ffSecondary)
                
                Button("Premium Button") {}
                    .buttonStyle(.ffPremium)
            }
            
            // Stats
            HStack(spacing: 24) {
                FFStatDisplay(value: "42", label: "Streak", icon: "flame.fill", color: .orange)
                FFStatDisplay(value: "128", label: "XP", icon: "sparkles", color: .purple)
                FFStatDisplay(value: "15", label: "Movies", icon: "film", color: .cyan)
            }
            
            // Badges
            HStack(spacing: 12) {
                FFBadge(text: "NEW", color: .green, size: .small)
                FFBadge(text: "PREMIUM", color: .orange)
                FFBadge(text: "EXCLUSIVE", color: .purple)
            }
            
            // Progress Ring
            FFProgressRing(progress: 0.7, color: .orange)
        }
        .padding()
    }
}
