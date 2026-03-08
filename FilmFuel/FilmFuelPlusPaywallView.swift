//
//  FilmFuelPlusPaywallView.swift
//  FilmFuel
//
//  UPDATED: Removed fake urgency timer, replaced with real value props
//  Key patterns: Social proof, loss aversion, anchoring, value stacking,
//  testimonials, risk reversal
//

import SwiftUI
import StoreKit
import Combine

struct FilmFuelPlusPaywallView: View {
    @EnvironmentObject var store: FilmFuelStore
    @EnvironmentObject var entitlements: FilmFuelEntitlements
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPlan: PlusPlan = .yearly
    @State private var showingTerms = false
    @State private var isProcessing = false
    @State private var pulseButton = false
    
    enum PlusPlan: String, CaseIterable {
        case monthly, yearly
        
        var title: String {
            switch self {
            case .monthly: return "Monthly"
            case .yearly:  return "Yearly"
            }
        }
        
        var price: String {
            switch self {
            case .monthly: return "$4.99"
            case .yearly:  return "$29.99"
            }
        }
        
        var perMonth: String {
            switch self {
            case .monthly: return "$4.99/mo"
            case .yearly:  return "$2.50/mo"
            }
        }
        
        var savings: String? {
            switch self {
            case .monthly: return nil
            case .yearly:  return "Save 50%"
            }
        }
        
        var badge: String? {
            switch self {
            case .monthly: return nil
            case .yearly:  return "BEST VALUE"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // NEW: Real value banner (not fake timer)
                    topBanner
                    
                    // Hero section
                    heroSection
                    
                    // Value proposition
                    valueStack
                    
                    // Plan selection
                    planSelector
                    
                    // CTA button
                    ctaButton
                    
                    // Risk reversal
                    riskReversal
                    
                    // What you're missing
                    missingOutSection
                    
                    // FAQ
                    faqSection
                    
                    // Legal
                    legalFooter
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        entitlements.recordPaywallDismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            // REMOVED: Fake timer receiver
        }
        .onAppear {
            store.recordPaywallView(trigger: .manualTap)
        }
    }
    
    // MARK: - Top Banner (REPLACED fake timer)
    
    private var topBanner: some View {
        Group {
            if entitlements.eligibleForTrial {
                // Real offer - free trial available
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .foregroundColor(.white)
                    
                    Text("Try FilmFuel+ free for 3 days")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("No commitment")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.teal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Evergreen value prop (no fake urgency)
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.white)
                    
                    Text("Join 10,000+ movie lovers")
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text("4.9")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.indigo],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 12) {
            // Animated sparkles icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundColor(.accentColor)
            }
            
            // IMPROVED: More compelling headline
            Text("Never Miss a\nPerfect Movie Night")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            
            Text("Smart recommendations that actually match your taste")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Social Proof
    
    // MARK: - Value Stack
    
    private var valueStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Everything you get:")
                .font(.headline)
                .padding(.bottom, 12)
            
            // Core features
            valueRow(icon: "infinity", iconColor: .accentColor, title: "Unlimited Smart Picks", subtitle: "No daily limits – discover all day", isHighlighted: true)
            valueRow(icon: "sparkles", iconColor: .purple, title: "Taste-Powered Recommendations", subtitle: "AI learns your unique preferences")
            valueRow(icon: "diamond.fill", iconColor: .cyan, title: "Hidden Gems Mode", subtitle: "Exclusive access to underrated films", badge: "EXCLUSIVE")
            valueRow(icon: "slider.horizontal.3", iconColor: .orange, title: "Advanced Filters", subtitle: "Actor, director, runtime & more")
            valueRow(icon: "person.2.fill", iconColor: .green, title: "Watch Together", subtitle: "Match movies with friends", badge: "COMING SOON")
            valueRow(icon: "trophy.fill", iconColor: .yellow, title: "Priority Support", subtitle: "Direct line to the dev team")
            
            // Value anchor
            HStack {
                Text("Total value:")
                Spacer()
                Text("$120+/year")
                    .strikethrough()
                    .foregroundColor(.secondary)
                Text("Just \(selectedPlan == .yearly ? "$29.99" : "$59.88")/year")
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            .font(.subheadline)
            .padding(.top, 16)
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func valueRow(icon: String, iconColor: Color, title: String, subtitle: String, isHighlighted: Bool = false, badge: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isHighlighted ? Color.accentColor.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Plan Selector
    
    private var planSelector: some View {
        VStack(spacing: 12) {
            Text("Choose your plan:")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(PlusPlan.allCases, id: \.self) { plan in
                    planCard(plan)
                }
            }
        }
    }
    
    private func planCard(_ plan: PlusPlan) -> some View {
        let isSelected = selectedPlan == plan
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPlan = plan
            }
        } label: {
            VStack(spacing: 8) {
                if let badge = plan.badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                } else {
                    Text(" ")
                        .font(.system(size: 10))
                        .padding(.vertical, 3)
                }
                
                Text(plan.title)
                    .font(.subheadline.weight(.semibold))
                
                Text(plan.price)
                    .font(.title2.weight(.bold))
                
                Text(plan.perMonth)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let savings = plan.savings {
                    Text(savings)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.green)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.15)
                    : Color(.secondarySystemBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - CTA Button
    
    private var ctaButton: some View {
        VStack(spacing: 8) {
            Button {
                isProcessing = true
                Task {
                    let productId = selectedPlan == .yearly ? "ff_plus_yearly" : "ff_plus_monthly"
                    if let product = store.plusProducts.first(where: { $0.id == productId }) {
                        let source: ConversionSource = selectedPlan == .yearly ? .manualUpgrade : .manualUpgrade
                        await store.purchase(product, source: source)
                    }
                    isProcessing = false
                }
            } label: {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        if entitlements.eligibleForTrial {
                            Text("Start Free Trial")
                                .font(.headline)
                        } else {
                            Text("Start FilmFuel+ Now")
                                .font(.headline)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .scaleEffect(pulseButton ? 1.02 : 1.0)
                .shadow(color: Color.accentColor.opacity(0.4), radius: 8, y: 4)
            }
            .disabled(isProcessing)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseButton = true
                }
            }
            
            // Restore purchases
            Button {
                Task {
                    await store.restorePurchases()
                }
            } label: {
                Text("Restore purchases")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Risk Reversal
    
    private var riskReversal: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.checkmark.fill")
                .font(.title2)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("100% Risk-Free")
                    .font(.subheadline.weight(.semibold))
                Text("Cancel anytime. No questions asked. Your data stays yours.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Missing Out Section (Loss Aversion)
    
    private var missingOutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("What you're missing on Free")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                missingRow("Only 2 smart picks per day")
                missingRow("No Hidden Gems access")
                missingRow("Basic filters only")
                missingRow("Limited taste learning")
                missingRow("No priority recommendations")
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func missingRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(.red.opacity(0.7))
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - FAQ
    
    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Questions?")
                .font(.headline)
            
            faqItem(
                question: "Can I cancel anytime?",
                answer: "Absolutely! Cancel with one tap in Settings. No fees, no hassle."
            )
            
            faqItem(
                question: "Will I lose my data if I cancel?",
                answer: "Never. Your favorites, watchlist, and taste profile are always yours."
            )
            
            faqItem(
                question: "Is the yearly plan worth it?",
                answer: "If you use FilmFuel even once a week, yearly saves you 50% – that's 6 months free!"
            )
        }
    }
    
    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(question)
                .font(.subheadline.weight(.semibold))
            Text(answer)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Legal Footer
    
    private var legalFooter: some View {
        VStack(spacing: 8) {
            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button("Terms of Service") {
                    showingTerms = true
                }
                Button("Privacy Policy") {
                    // Open privacy policy
                }
            }
            .font(.caption2)
            .foregroundColor(.accentColor)
        }
        .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview {
    FilmFuelPlusPaywallView()
        .environmentObject(FilmFuelStore())
        .environmentObject(FilmFuelEntitlements())
}
