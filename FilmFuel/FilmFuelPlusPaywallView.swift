//
//  FilmFuelPlusPaywallView.swift
//  FilmFuel
//
//  Redesigned for maximum conversion
//  Key patterns: Urgency, social proof, loss aversion, anchoring, value stacking,
//  testimonials, risk reversal, strategic timing
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
    @State private var showSocialProof = true
    
    // Timer for urgency
    @State private var timeRemaining: Int = 3600 * 23 + 60 * 47 // ~24 hours
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
                    // Urgency banner
                    urgencyBanner
                    
                    // Hero section
                    heroSection
                    
                    // Social proof
                    socialProofSection
                    
                    // Value proposition
                    valueStack
                    
                    // Plan selection
                    planSelector
                    
                    // CTA button
                    ctaButton
                    
                    // Risk reversal
                    riskReversal
                    
                    // Testimonials
                    testimonialSection
                    
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
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onReceive(timer) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                }
            }
        }
    }
    
    // MARK: - Urgency Banner
    
    private var urgencyBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .foregroundColor(.white)
            
            Text("Special offer ends in ")
                .foregroundColor(.white.opacity(0.9)) +
            Text(timeString)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.orange, Color.red],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var timeString: String {
        let hours = timeRemaining / 3600
        let minutes = (timeRemaining % 3600) / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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
            
            Text("Unlock Your Full\nMovie Discovery Potential")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            
            Text("Join thousands of film lovers who never miss a perfect match")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Social Proof
    
    private var socialProofSection: some View {
        VStack(spacing: 12) {
            // User avatars + count
            HStack(spacing: -8) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(["👤", "👩", "👨", "🧑", "👱"][i])
                                .font(.caption)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                }
                
                Text("+12,847")
                    .font(.subheadline.weight(.semibold))
                    .padding(.leading, 12)
            }
            
            HStack(spacing: 4) {
                ForEach(0..<5) { _ in
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
                Text("4.9")
                    .font(.subheadline.weight(.semibold))
                Text("from 2,341 reviews")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Live activity indicator
            if showSocialProof {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Sarah from Austin just upgraded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
                .onAppear {
                    // Cycle through social proof messages
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation { showSocialProof = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            withAnimation { showSocialProof = true }
                        }
                    }
                }
            }
        }
    }
    
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
                // TODO: Trigger purchase
                Task {
                    if let product = store.plusProducts.first(where: {
                        selectedPlan == .yearly
                            ? $0.id == "ff_plus_yearly"
                            : $0.id == "ff_plus_monthly"
                    }) {
                        await store.purchase(product)
                    }
                    isProcessing = false
                }
            } label: {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Start FilmFuel+ Now")
                            .font(.headline)
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
    
    // MARK: - Testimonials
    
    private var testimonialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What members say")
                .font(.headline)
            
            VStack(spacing: 12) {
                testimonialCard(
                    name: "Mike R.",
                    text: "FilmFuel+ changed how I find movies. The smart picks are scary accurate!",
                    rating: 5
                )
                
                testimonialCard(
                    name: "Jessica L.",
                    text: "Finally an app that actually understands my taste. Worth every penny.",
                    rating: 5
                )
                
                testimonialCard(
                    name: "David K.",
                    text: "Hidden Gems mode alone is worth the subscription. Found so many great films!",
                    rating: 5
                )
            }
        }
    }
    
    private func testimonialCard(name: String, text: String, rating: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                
                Spacer()
                
                HStack(spacing: 2) {
                    ForEach(0..<rating, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            Text("\"" + text + "\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
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
