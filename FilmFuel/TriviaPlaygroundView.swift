import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Enhanced Unlimited Trivia View

struct TriviaPlaygroundView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var entitlements: FilmFuelEntitlements

    // Persisted stats
    @AppStorage("ff.unlimited.bestStreak") private var bestUnlimitedStreak: Int = 0
    @AppStorage("ff.unlimited.totalAnswered") private var totalAnswered: Int = 0
    @AppStorage("ff.unlimited.totalCorrect") private var totalCorrect: Int = 0

    // Current question state
    @State private var currentQuestion: TriviaQuestion?
    @State private var selectedIndex: Int? = nil
    @State private var reveal = false
    @State private var isCorrect = false
    @State private var answersAppeared = false
    @State private var showConfetti = false
    @State private var cardBounce = false

    // Session stats
    @State private var questionsAnswered: Int = 0
    @State private var correctAnswers: Int = 0
    @State private var sessionStreak: Int = 0
    @State private var bestSessionStreak: Int = 0

    // UI states
    @State private var showSummarySheet: Bool = false
    @State private var milestoneMessage: String? = nil
    @State private var headerAppeared = false
    @State private var showPowerUp = false
    @State private var fiftyFiftyUsed = false
    @State private var eliminatedOptions: Set<Int> = []
    
    // Combo system
    @State private var comboMultiplier: Int = 1
    @State private var comboTimer: Int = 0
    @State private var showComboExpiring = false
    
    // Category tracking
    @State private var currentCategory: String = "Mixed"
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Computed Properties

    private var accuracyPercent: Int {
        guard questionsAnswered > 0 else { return 0 }
        return Int((Double(correctAnswers) / Double(questionsAnswered)) * 100)
    }
    
    private var allTimeAccuracy: Int {
        guard totalAnswered > 0 else { return 0 }
        return Int((Double(totalCorrect) / Double(totalAnswered)) * 100)
    }

    private var accentColor: Color { .orange }
    
    private var comboColor: Color {
        switch comboMultiplier {
        case 1: return .orange
        case 2: return .yellow
        case 3: return .green
        case 4...: return .purple
        default: return .orange
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated background
                AnimatedPlaygroundBackground(intensity: Double(comboMultiplier) * 0.1)

                VStack(spacing: 8) {
                    // Header with stats
                    headerSection
                        .opacity(headerAppeared ? 1 : 0)
                        .offset(y: headerAppeared ? 0 : -20)

                    if let q = currentQuestion {
                        // Main quiz card
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 12) {
                                quizCard(trivia: q)
                                    .id(q.id)
                                    .scaleEffect(cardBounce ? 1.0 : 0.97)
                                    .animation(
                                        .spring(response: 0.5, dampingFraction: 0.8),
                                        value: cardBounce
                                    )
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))

                                // Power-ups (premium feature)
                                if !reveal && !fiftyFiftyUsed {
                                    powerUpSection
                                        .padding(.horizontal)
                                }

                                if !reveal {
                                    submitButton(correctIndex: q.correctIndex)
                                        .padding(.horizontal)
                                } else {
                                    resultSection(trivia: q)
                                        .padding(.horizontal)
                                }
                                
                                Spacer(minLength: 100)
                            }
                        }
                    } else {
                        emptyStateView
                    }
                }
                .padding(.top, 4)

                // Bottom session bar (floating)
                VStack {
                    Spacer()
                    sessionBar
                        .padding(.bottom, 8)
                }

                // Overlays
                if showConfetti {
                    EnhancedConfettiView()
                        .transition(.opacity)
                }

                // Milestone banner
                if let message = milestoneMessage {
                    VStack {
                        MilestoneBanner(text: message)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.top, 16)
                        Spacer()
                    }
                }
                
                // Combo expiring warning
                if showComboExpiring && comboMultiplier > 1 {
                    VStack {
                        ComboExpiringBanner(seconds: comboTimer, multiplier: comboMultiplier)
                            .transition(.opacity)
                            .padding(.top, milestoneMessage != nil ? 70 : 16)
                        Spacer()
                    }
                }
            }
            .onAppear {
                appModel.loadTriviaIfNeeded()
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) {
                    headerAppeared = true
                }

                if currentQuestion == nil {
                    loadNextQuestion()
                }
            }
            .onReceive(timer) { _ in
                handleComboTimer()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if questionsAnswered > 0 {
                            showSummarySheet = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .imageScale(.medium)
                            .fontWeight(.semibold)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    // All-time best badge
                    if bestUnlimitedStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .imageScale(.small)
                                .foregroundStyle(.yellow)
                            
                            Text("\(bestUnlimitedStreak)")
                                .font(.caption.weight(.bold).monospacedDigit())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.yellow.opacity(0.15))
                        )
                    }
                }
            }
            .sheet(isPresented: $showSummarySheet) {
                SessionSummarySheet(
                    questionsAnswered: questionsAnswered,
                    correctAnswers: correctAnswers,
                    accuracyPercent: accuracyPercent,
                    bestSessionStreak: bestSessionStreak,
                    allTimeBest: bestUnlimitedStreak,
                    totalAnswered: totalAnswered,
                    totalCorrect: totalCorrect,
                    onContinue: { showSummarySheet = false },
                    onEnd: { dismiss() }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 10) {
            // Title card
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Endless Trivia")
                        .font(.title3.weight(.bold))
                    
                    Text("Keep your streak alive!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Live combo indicator
                if comboMultiplier > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .symbolEffect(.pulse, options: .repeating)
                        
                        Text("\(comboMultiplier)x")
                            .font(.headline.weight(.black).monospacedDigit())
                    }
                    .foregroundStyle(comboColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(comboColor.opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            .stroke(comboColor.opacity(0.5), lineWidth: 2)
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)

            // Quick stats row
            HStack(spacing: 0) {
                quickStat(icon: "number", value: "\(questionsAnswered)", label: "Played")
                
                Divider().frame(height: 28)
                
                quickStat(icon: "checkmark", value: "\(correctAnswers)", label: "Correct")
                
                Divider().frame(height: 28)
                
                quickStat(icon: "percent", value: "\(accuracyPercent)%", label: "Accuracy")
                
                Divider().frame(height: 28)
                
                quickStat(
                    icon: "flame.fill",
                    value: "\(sessionStreak)",
                    label: "Streak",
                    highlight: sessionStreak >= 3
                )
            }
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 20)
        }
    }
    
    private func quickStat(icon: String, value: String, label: String, highlight: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .imageScale(.small)
                .foregroundStyle(highlight ? .orange : .secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(highlight ? .orange : .primary)
                
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quiz Card

    @ViewBuilder
    private func quizCard(trivia: TriviaQuestion) -> some View {
        VStack(spacing: 14) {
            // Movie & category header
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text("Q\(questionsAnswered + 1)")
                        .font(.caption.weight(.black))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(accentColor.opacity(0.15))
                        )
                        .foregroundStyle(accentColor)
                    
                    if sessionStreak >= 3 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .imageScale(.small)
                            Text("Hot!")
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                    }
                }

                Text(trivia.movieTitle)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                
                if trivia.year > 0 {
                    Text(String(trivia.year))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Question
            Text(trivia.question)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.85)
                .padding(.horizontal)
                .padding(.top, 4)

            // Answers
            VStack(spacing: 8) {
                ForEach(trivia.options.indices, id: \.self) { i in
                    if !eliminatedOptions.contains(i) {
                        EnhancedAnswerRow(
                            text: trivia.options[i],
                            index: i,
                            selectedIndex: selectedIndex,
                            correctIndex: trivia.correctIndex,
                            reveal: reveal,
                            reviewMode: false
                        ) {
                            guard !reveal else { return }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedIndex = i
                            }
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            #endif
                        }
                        .opacity(answersAppeared ? 1 : 0)
                        .offset(y: answersAppeared ? 0 : 10)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.85)
                                .delay(Double(i) * 0.04),
                            value: answersAppeared
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    comboMultiplier > 1
                        ? comboColor.opacity(0.4)
                        : Color.white.opacity(0.2),
                    lineWidth: comboMultiplier > 1 ? 2 : 1
                )
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Power-ups Section
    
    private var powerUpSection: some View {
        HStack(spacing: 12) {
            PowerUpButton(
                icon: "divide.circle",
                title: "50/50",
                subtitle: entitlements.isPlus ? "Eliminate 2" : "Pro",
                isLocked: !entitlements.isPlus,
                action: {
                    if entitlements.isPlus {
                        useFiftyFifty()
                    }
                }
            )
            
            PowerUpButton(
                icon: "clock.arrow.circlepath",
                title: "Skip",
                subtitle: entitlements.isPlus ? "No penalty" : "Pro",
                isLocked: !entitlements.isPlus,
                action: {
                    if entitlements.isPlus {
                        loadNextQuestion()
                    }
                }
            )
        }
    }
    
    private func useFiftyFifty() {
        guard let q = currentQuestion else { return }
        
        fiftyFiftyUsed = true
        
        // Eliminate 2 wrong answers
        var wrongIndices = q.options.indices.filter { $0 != q.correctIndex }
        wrongIndices.shuffle()
        
        let toEliminate = Set(wrongIndices.prefix(2))
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            eliminatedOptions = toEliminate
        }
        
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    // MARK: - Submit Button

    private func submitButton(correctIndex: Int) -> some View {
        Button {
            submitSelected(correctIndex: correctIndex)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Check Answer")
                    .font(.headline.weight(.bold))
                
                if comboMultiplier > 1 {
                    Text("(\(comboMultiplier)x)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(comboColor)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if selectedIndex != nil {
                        LinearGradient(
                            colors: [Color.orange, Color.red.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.secondary.opacity(0.3)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            .foregroundStyle(.white)
            .shadow(
                color: selectedIndex != nil ? .orange.opacity(0.4) : .clear,
                radius: 12,
                y: 6
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedIndex == nil)
    }

    // MARK: - Result Section

    @ViewBuilder
    private func resultSection(trivia: TriviaQuestion) -> some View {
        VStack(spacing: 12) {
            // Quick result indicator
            HStack(spacing: 12) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(isCorrect ? .green : .red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isCorrect ? "Correct!" : "Not quite!")
                        .font(.headline.weight(.bold))
                    
                    if isCorrect && comboMultiplier > 1 {
                        Text("\(comboMultiplier)x combo bonus!")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(comboColor)
                    }
                }
                
                Spacer()
                
                if isCorrect {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                        Text("\(sessionStreak)")
                            .font(.headline.monospacedDigit().bold())
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isCorrect ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Answer reveal
            if !isCorrect {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    
                    Text("Answer: \(safeAnswerText(trivia: trivia))")
                        .font(.subheadline.weight(.medium))
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.yellow.opacity(0.1))
                )
            }

            // Next button
            Button {
                loadNextQuestion()
            } label: {
                HStack(spacing: 8) {
                    Text(isCorrect ? "Keep Going!" : "Try Another")
                        .font(.headline.weight(.bold))
                    
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Session Bar

    private var sessionBar: some View {
        HStack(spacing: 12) {
            // Session info
            HStack(spacing: 8) {
                Image(systemName: "gamecontroller.fill")
                    .imageScale(.small)
                
                Text("\(questionsAnswered) played")
                    .font(.caption.weight(.medium))
                
                Text("•")
                    .foregroundStyle(.secondary)
                
                Text("\(accuracyPercent)% accuracy")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary)
            
            Spacer()
            
            // End session button
            Button {
                showSummarySheet = true
            } label: {
                Text("End")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(.secondarySystemBackground))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: -2)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Loading trivia...")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Button {
                appModel.loadTriviaIfNeeded()
                loadNextQuestion()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
    }

    // MARK: - Logic

    private func loadNextQuestion() {
        guard let candidate = appModel.nextEndlessTriviaQuestion() else { return }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
            currentQuestion = candidate
            selectedIndex = nil
            reveal = false
            isCorrect = false
            answersAppeared = false
            cardBounce = false
            fiftyFiftyUsed = false
            eliminatedOptions = []
        }

        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                answersAppeared = true
                cardBounce = true
            }
        }
        
        // Reset combo timer on new question
        if comboMultiplier > 1 {
            comboTimer = 15
        }
    }

    private func submitSelected(correctIndex: Int) {
        guard let sel = selectedIndex, !reveal else { return }
        let correct = (sel == correctIndex)
        isCorrect = correct

        // Update stats
        questionsAnswered += 1
        totalAnswered += 1
        
        StatsManager.shared.trackEndlessTriviaAnswer(correct: correct)

        let milestoneCounts = [5, 10, 20, 30]
        if milestoneCounts.contains(questionsAnswered) {
            RateManager.shared.trackTriviaCompleted()
        }

        if correct {
            correctAnswers += 1
            totalCorrect += 1
            sessionStreak += 1
            bestSessionStreak = max(bestSessionStreak, sessionStreak)
            bestUnlimitedStreak = max(bestUnlimitedStreak, sessionStreak)
            
            // Update combo
            comboMultiplier = min(4, comboMultiplier + 1)
            comboTimer = 15
            showComboExpiring = false

            // Milestones
            let streakMilestones = [5, 10, 15, 20, 25, 50]
            if streakMilestones.contains(sessionStreak) {
                showMilestone("🔥 \(sessionStreak)-answer streak!")
            } else if sessionStreak == bestUnlimitedStreak && sessionStreak > 1 {
                showMilestone("🏆 New all-time record!")
            }
            
            triggerConfetti()

        } else {
            sessionStreak = 0
            comboMultiplier = 1
            comboTimer = 0
            showComboExpiring = false
        }

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
        #endif

        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
            reveal = true
        }
    }
    
    private func handleComboTimer() {
        guard comboMultiplier > 1 && !reveal else { return }
        
        if comboTimer > 0 {
            comboTimer -= 1
            
            if comboTimer <= 5 && comboTimer > 0 {
                withAnimation {
                    showComboExpiring = true
                }
            }
            
            if comboTimer == 0 {
                withAnimation {
                    comboMultiplier = 1
                    showComboExpiring = false
                }
            }
        }
    }
    
    private func showMilestone(_ text: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            milestoneMessage = text
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                milestoneMessage = nil
            }
        }
    }

    private func triggerConfetti() {
        showConfetti = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showConfetti = false
            }
        }
    }

    private func safeAnswerText(trivia: TriviaQuestion) -> String {
        let idx = trivia.correctIndex
        guard idx >= 0 && idx < trivia.options.count else { return "" }
        return trivia.options[idx]
    }
}

// MARK: - Animated Background

private struct AnimatedPlaygroundBackground: View {
    let intensity: Double
    @State private var animate = false
    
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
            
            // Floating accent circles
            GeometryReader { geo in
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(Color.orange.opacity(0.03 + intensity * 0.02))
                        .frame(width: 150 + CGFloat(i) * 50, height: 150 + CGFloat(i) * 50)
                        .blur(radius: 50)
                        .offset(
                            x: animate ? CGFloat.random(in: -30...30) : 0,
                            y: animate ? CGFloat.random(in: -20...20) : 0
                        )
                        .position(
                            x: geo.size.width * CGFloat([0.2, 0.8, 0.3, 0.7][i]),
                            y: geo.size.height * CGFloat([0.2, 0.3, 0.7, 0.8][i])
                        )
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 5)
                .repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
    }
}

// MARK: - Power-up Button

private struct PowerUpButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let isLocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isLocked ? "lock.fill" : icon)
                    .imageScale(.small)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                if isLocked {
                    Image(systemName: "crown.fill")
                        .imageScale(.small)
                        .foregroundStyle(.yellow)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isLocked ? Color(.secondarySystemBackground) : Color.blue.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isLocked ? Color.clear : Color.blue.opacity(0.3), lineWidth: 1)
            )
            .foregroundStyle(isLocked ? Color.secondary : Color.blue)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }
}

// MARK: - Milestone Banner

private struct MilestoneBanner: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Text(text)
                .font(.subheadline.weight(.bold))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThickMaterial)
                .shadow(color: .orange.opacity(0.3), radius: 12, y: 4)
        )
        .overlay(
            Capsule()
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Combo Expiring Banner

private struct ComboExpiringBanner: View {
    let seconds: Int
    let multiplier: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .symbolEffect(.pulse, options: .repeating)
            
            Text("\(multiplier)x combo expiring in \(seconds)s!")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.9))
        )
        .foregroundStyle(.white)
    }
}

// MARK: - Session Summary Sheet

private struct SessionSummarySheet: View {
    let questionsAnswered: Int
    let correctAnswers: Int
    let accuracyPercent: Int
    let bestSessionStreak: Int
    let allTimeBest: Int
    let totalAnswered: Int
    let totalCorrect: Int
    let onContinue: () -> Void
    let onEnd: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                
                Text("Session Summary")
                    .font(.title2.weight(.bold))
            }
            .padding(.top, 20)
            
            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                SummaryStatCard(
                    icon: "number.circle.fill",
                    title: "Questions",
                    value: "\(questionsAnswered)",
                    color: .blue
                )
                
                SummaryStatCard(
                    icon: "checkmark.circle.fill",
                    title: "Correct",
                    value: "\(correctAnswers)",
                    color: .green
                )
                
                SummaryStatCard(
                    icon: "percent",
                    title: "Accuracy",
                    value: "\(accuracyPercent)%",
                    color: .purple
                )
                
                SummaryStatCard(
                    icon: "flame.fill",
                    title: "Best Streak",
                    value: "\(bestSessionStreak)",
                    color: .orange
                )
            }
            .padding(.horizontal)
            
            // All-time stats
            VStack(spacing: 8) {
                Text("All-Time Stats")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 20) {
                    VStack {
                        Text("\(totalAnswered)")
                            .font(.headline.monospacedDigit().bold())
                        Text("Total Played")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider().frame(height: 30)
                    
                    VStack {
                        Text("\(totalCorrect)")
                            .font(.headline.monospacedDigit().bold())
                        Text("Total Correct")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider().frame(height: 30)
                    
                    VStack {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .imageScale(.small)
                                .foregroundStyle(.yellow)
                            Text("\(allTimeBest)")
                                .font(.headline.monospacedDigit().bold())
                        }
                        Text("Best Ever")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal)
            
            Spacer()
            
            // Actions
            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("Keep Playing")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.orange)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: onEnd) {
                    Text("End Session")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
}

private struct SummaryStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title.weight(.bold).monospacedDigit())
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Stat Pill (for header)

private struct StatPill: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .imageScale(.medium)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

