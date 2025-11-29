import SwiftUI
#if canImport(UIKit)
import UIKit
import Combine
#endif

// MARK: - Daily Quiz View

struct QuizView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var entitlements: FilmFuelEntitlements

    @State private var selectedIndex: Int? = nil
    @State private var reveal = false
    @State private var isCorrect = false
    @State private var showShare = false
    @State private var reviewMode = false
    @State private var showConfetti = false
    @State private var answersAppeared = false
    @State private var showMoreTriviaSheet = false
    @State private var showMoreButton = false
    
    // New engagement states
    @State private var headerAppeared = false
    @State private var cardAppeared = false
    @State private var showHint = false
    @State private var hintUsed = false
    @State private var timeRemaining: Int = 30
    @State private var timerActive = false
    @State private var showTimerWarning = false
    @State private var streakAnimation = false
    
    // Timer for optional timed mode
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var trivia: TriviaQuestion? { appModel.todayTrivia }
    private var quoteMovie: String { trivia?.movieTitle ?? "Today's Movie" }
    private var quoteYear: Int { trivia?.year ?? 0 }
    
    // Computed difficulty indicator
    private var difficultyLevel: String {
        guard let t = trivia else { return "Medium" }
        // You can customize this based on your trivia data
        return t.options.count > 4 ? "Hard" : "Medium"
    }
    
    private var difficultyColor: Color {
        switch difficultyLevel {
        case "Hard": return .red
        case "Easy": return .green
        default: return .orange
        }
    }

    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedQuizBackground()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    headerSection
                        .opacity(headerAppeared ? 1 : 0)
                        .offset(y: headerAppeared ? 0 : -20)

                    if let trivia {
                        quizCard(trivia: trivia)
                            .padding(.horizontal)
                            .opacity(cardAppeared ? 1 : 0)
                            .scaleEffect(cardAppeared ? 1 : 0.95)

                        // Hint button (premium feature teaser)
                        if !reveal && !reviewMode && !hintUsed {
                            hintButton(trivia: trivia)
                                .padding(.horizontal)
                        }

                        submitButtonSection(trivia: trivia)
                            .padding(.horizontal)

                        resultSection(trivia: trivia)
                            .padding(.horizontal)
                    } else {
                        loadingSection()
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }

            // Confetti overlay
            if showConfetti {
                EnhancedConfettiView()
                    .transition(.opacity)
            }

            // Toast overlays
            VStack {
                if appModel.showNewRecordToast {
                    RecordBanner(streak: appModel.bestCorrectStreak)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
                
                if showTimerWarning && !reveal {
                    TimerWarningBanner(seconds: timeRemaining)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, appModel.showNewRecordToast ? 60 : 8)
                }
                
                Spacer()
            }
        }
        .onAppear {
            appModel.ensureTodayTrivia()

            if appModel.quizCompletedToday {
                reviewMode = true
                reveal = true
                showMoreButton = true
            }

            // Staggered entrance animations
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) {
                headerAppeared = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.2)) {
                cardAppeared = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    answersAppeared = true
                }
            }
        }
        .onChange(of: reveal) {
            if reveal {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) {
                    showMoreButton = true
                }
            }
        }
        .onReceive(timer) { _ in
            guard timerActive && !reveal && !reviewMode else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
                if timeRemaining == 10 {
                    withAnimation {
                        showTimerWarning = true
                    }
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                }
            }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(activityItems: [shareMessage()])
        }
        .fullScreenCover(isPresented: $showMoreTriviaSheet) {
            TriviaPlaygroundView()
                .environmentObject(appModel)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .imageScale(.medium)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Today's Quiz")
                            .font(.title3.weight(.bold))
                        
                        // Difficulty badge
                        Text(difficultyLevel)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(difficultyColor.opacity(0.15))
                            )
                            .foregroundStyle(difficultyColor)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "film")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                        
                        Text(quoteYear == 0 ? quoteMovie : "\(quoteMovie) • \(quoteYear)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }

                Spacer(minLength: 8)

                // Streak display
                if appModel.correctStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .imageScale(.small)
                            .symbolEffect(.bounce, value: streakAnimation)
                        
                        Text("\(appModel.correctStreak)")
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

                // Share button
                Button {
                    showShare = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .imageScale(.medium)
                        .font(.body.weight(.semibold))
                        .padding(10)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                .accessibilityLabel("Share today's quiz")
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Progress indicator for daily streaks
            if appModel.dailyStreak > 0 || appModel.bestCorrectStreak > 0 {
                HStack(spacing: 16) {
                    statBadge(
                        icon: "calendar",
                        value: "\(appModel.dailyStreak)",
                        label: "Day Streak"
                    )
                    
                    Divider()
                        .frame(height: 24)
                    
                    statBadge(
                        icon: "trophy.fill",
                        value: "\(appModel.bestCorrectStreak)",
                        label: "Best"
                    )
                    
                    if !reviewMode && !reveal {
                        Divider()
                            .frame(height: 24)
                        
                        statBadge(
                            icon: "questionmark.circle",
                            value: "1",
                            label: "Question"
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .padding(.horizontal)
            }
        }
    }
    
    private func statBadge(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .imageScale(.small)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption.weight(.bold).monospacedDigit())
                
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Loading Section

    @ViewBuilder
    private func loadingSection() -> some View {
        VStack(spacing: 16) {
            // Animated loading indicator
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: true)
            }
            
            Text("Loading today's quiz...")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)

            Button {
                appModel.ensureTodayTrivia()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding()
    }

    // MARK: - Quiz Card

    @ViewBuilder
    private func quizCard(trivia: TriviaQuestion) -> some View {
        VStack(spacing: 16) {
            // Question header
            VStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                Text(trivia.question)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .lineLimit(4)
                    .minimumScaleFactor(0.85)
            }
            .padding(.top, 16)

            // Answer options
            VStack(spacing: 10) {
                ForEach(trivia.options.indices, id: \.self) { i in
                    EnhancedAnswerRow(
                        text: trivia.options[i],
                        index: i,
                        selectedIndex: selectedIndex,
                        correctIndex: trivia.correctIndex,
                        reveal: reveal,
                        reviewMode: reviewMode,
                        isHinted: showHint && i == trivia.correctIndex
                    ) {
                        guard !reveal, !reviewMode else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedIndex = i
                        }
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        #endif
                    }
                    .opacity(answersAppeared ? 1 : 0)
                    .offset(y: answersAppeared ? 0 : 12)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.85)
                            .delay(Double(i) * 0.06),
                        value: answersAppeared
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)

            // Extra info footer
            if let extra = trivia.extraInfo, reveal {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .imageScale(.small)
                        .foregroundStyle(.yellow)
                    
                    Text(extra)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.9)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.yellow.opacity(0.1))
                )
                .padding(.horizontal)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
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
    }
    
    // MARK: - Hint Button (Premium Teaser)
    
    @ViewBuilder
    private func hintButton(trivia: TriviaQuestion) -> some View {
        Button {
            if entitlements.isPlus {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showHint = true
                    hintUsed = true
                }
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            } else {
                // Show premium upsell
                // You can trigger your paywall here
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: entitlements.isPlus ? "lightbulb.fill" : "lock.fill")
                    .imageScale(.small)
                
                Text(entitlements.isPlus ? "Use Hint" : "Unlock Hints with Pro")
                    .font(.caption.weight(.semibold))
                
                if !entitlements.isPlus {
                    Image(systemName: "crown.fill")
                        .imageScale(.small)
                        .foregroundStyle(.yellow)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(entitlements.isPlus ? Color.yellow.opacity(0.15) : Color(.secondarySystemBackground))
            )
            .foregroundStyle(entitlements.isPlus ? .yellow : .secondary)
        }
    }

    // MARK: - Submit Button

    @ViewBuilder
    private func submitButtonSection(trivia: TriviaQuestion) -> some View {
        if !reviewMode && !reveal {
            Button {
                submitSelected(correctIndex: trivia.correctIndex)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Check Answer")
                        .font(.headline.weight(.bold))
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
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedIndex)
        }
    }

    // MARK: - Result Section

    @ViewBuilder
    private func resultSection(trivia: TriviaQuestion) -> some View {
        if reveal {
            VStack(spacing: 16) {
                EnhancedResultPanel(
                    reviewMode: reviewMode,
                    isCorrect: reviewMode ? appModel.lastResultWasCorrect : isCorrect,
                    triviaQuestion: trivia.question,
                    triviaAnswer: safeAnswerText(trivia: trivia),
                    movieTitle: quoteMovie,
                    movieYear: quoteYear,
                    streakCount: appModel.correctStreak,
                    isNewRecord: appModel.correctStreak == appModel.bestCorrectStreak && appModel.correctStreak > 1
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))

                if reviewMode {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .imageScale(.small)
                        Text("New quiz unlocks tomorrow")
                            .font(.footnote)
                    }
                    .foregroundStyle(.secondary)
                }

                // Primary CTA: More Trivia
                Button {
                    showMoreTriviaSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "infinity")
                        Text("Play More Trivia")
                            .font(.headline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.black, Color(.darkGray)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    )
                    .foregroundStyle(.white)
                    .shadow(radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .scaleEffect(showMoreButton ? 1.0 : 0.9)
                .opacity(showMoreButton ? 1.0 : 0.0)
                
                // Secondary CTA: Share
                Button {
                    showShare = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Result")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .opacity(showMoreButton ? 1.0 : 0.0)
            }
        }
    }

    // MARK: - Actions

    private func submitSelected(correctIndex: Int) {
        guard let sel = selectedIndex, !reveal else { return }
        let correct = (sel == correctIndex)
        isCorrect = correct

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
        #endif

        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
            reveal = true
            showTimerWarning = false
        }

        if correct {
            triggerConfetti()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                streakAnimation.toggle()
            }
        }

        appModel.registerAnswer(correct: correct)
    }

    private func triggerConfetti() {
        showConfetti = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showConfetti = false
            }
        }
    }

    private func shareMessage() -> String {
        let movie = quoteMovie
        let yearPart = quoteYear == 0 ? "" : " (\(quoteYear))"
        let resultEmoji = isCorrect ? "✅" : "🎬"
        
        var lines: [String] = []
        lines.append("FilmFuel Daily Quiz 🎬")
        lines.append("\(movie)\(yearPart)")
        lines.append("")
        lines.append("\(resultEmoji) \(isCorrect ? "Got it right!" : "Tricky one!")")
        lines.append("🔥 Streak: \(appModel.correctStreak)")
        lines.append("")
        lines.append("Play daily trivia on FilmFuel!")
        
        return lines.joined(separator: "\n")
    }

    private func safeAnswerText(trivia: TriviaQuestion) -> String {
        let idx = trivia.correctIndex
        guard idx >= 0 && idx < trivia.options.count else { return "" }
        return trivia.options[idx]
    }
}

// MARK: - Animated Quiz Background

private struct AnimatedQuizBackground: View {
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
            
            // Subtle floating shapes
            GeometryReader { geo in
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.orange.opacity(0.05))
                        .frame(width: 200, height: 200)
                        .blur(radius: 60)
                        .offset(
                            x: animate ? CGFloat.random(in: -50...50) : 0,
                            y: animate ? CGFloat.random(in: -30...30) : 0
                        )
                        .position(
                            x: CGFloat(i) * geo.size.width / 2,
                            y: geo.size.height * 0.3
                        )
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 6)
                .repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
    }
}

// MARK: - Enhanced Answer Row

struct EnhancedAnswerRow: View {
    let text: String
    let index: Int
    let selectedIndex: Int?
    let correctIndex: Int
    let reveal: Bool
    let reviewMode: Bool
    var isHinted: Bool = false
    let onTap: () -> Void

    var isSelected: Bool { selectedIndex == index }
    var isCorrectChoice: Bool { index == correctIndex }

    var body: some View {
        Button(action: {
            guard !reveal, !reviewMode else { return }
            onTap()
        }) {
            HStack(spacing: 12) {
                // Status indicator
                statusIcon
                    .frame(width: 24, height: 24)

                Text(text)
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.92)

                // Result badge
                if reveal || reviewMode {
                    resultBadge
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(AnswerButtonStyle())
        .background(backgroundStyle)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(borderStyle, lineWidth: isSelected || (reveal && isCorrectChoice) ? 2 : 1)
        )
        .scaleEffect(reveal && isCorrectChoice ? 1.02 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: reveal)
        .accessibilityLabel(accessibilityDescription)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        if reviewMode {
            if isCorrectChoice {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary.opacity(0.4))
            }
        } else if reveal {
            if isCorrectChoice {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: reveal)
            } else if isSelected {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            }
        } else {
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.orange : Color.secondary.opacity(0.3), lineWidth: 2)
                
                if isSelected {
                    Circle()
                        .fill(Color.orange)
                        .padding(4)
                }
                
                // Hint glow
                if isHinted {
                    Circle()
                        .fill(Color.yellow.opacity(0.3))
                        .blur(radius: 4)
                }
            }
        }
    }
    
    @ViewBuilder
    private var resultBadge: some View {
        if reviewMode && isCorrectChoice {
            Text("Answer")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.15))
                )
                .foregroundStyle(.green)
        } else if reveal && isCorrectChoice && !isSelected {
            Text("Correct")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.15))
                )
                .foregroundStyle(.green)
        } else if reveal && isSelected && !isCorrectChoice {
            Text("Your pick")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.15))
                )
                .foregroundStyle(.red)
        }
    }

    private var backgroundStyle: Color {
        if reviewMode {
            return isCorrectChoice ? Color.green.opacity(0.08) : Color(.secondarySystemBackground)
        }
        if reveal {
            if isCorrectChoice { return Color.green.opacity(0.12) }
            if isSelected { return Color.red.opacity(0.1) }
            return Color(.tertiarySystemFill)
        } else if isSelected {
            return Color.orange.opacity(0.1)
        } else if isHinted {
            return Color.yellow.opacity(0.1)
        }
        return Color(.secondarySystemBackground)
    }

    private var borderStyle: Color {
        if reviewMode {
            return isCorrectChoice ? Color.green.opacity(0.4) : Color.secondary.opacity(0.15)
        }
        if reveal {
            if isCorrectChoice { return Color.green.opacity(0.6) }
            if isSelected { return Color.red.opacity(0.5) }
            return Color.secondary.opacity(0.15)
        } else if isSelected {
            return Color.orange.opacity(0.6)
        } else if isHinted {
            return Color.yellow.opacity(0.5)
        }
        return Color.secondary.opacity(0.15)
    }

    private var accessibilityDescription: String {
        if reviewMode || reveal {
            if isCorrectChoice {
                return "\(text), correct answer"
            } else if isSelected {
                return "\(text), your choice, incorrect"
            }
        }
        return text
    }
}

// Answer button style
struct AnswerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - Enhanced Result Panel

struct EnhancedResultPanel: View {
    let reviewMode: Bool
    let isCorrect: Bool?
    let triviaQuestion: String
    let triviaAnswer: String
    let movieTitle: String
    let movieYear: Int
    let streakCount: Int
    let isNewRecord: Bool

    private var yearText: String { String(movieYear) }

    var verdictText: String {
        if let correct = isCorrect {
            return correct ? "Correct! 🎯" : "Not quite! 💭"
        }
        return reviewMode ? "Already Played" : "Result"
    }

    var verdictColor: Color {
        if let c = isCorrect { return c ? .green : .orange }
        return .secondary
    }
    
    var verdictIcon: String {
        if let correct = isCorrect {
            return correct ? "checkmark.seal.fill" : "xmark.seal.fill"
        }
        return "lock.fill"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Verdict header
            VStack(spacing: 8) {
                Image(systemName: verdictIcon)
                    .font(.largeTitle)
                    .foregroundStyle(verdictColor)
                    .symbolEffect(.bounce, value: isCorrect)
                
                Text(verdictText)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(verdictColor)

                Text("From \(movieTitle) (\(yearText))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // Streak display for correct answers
                if let correct = isCorrect, correct, streakCount > 1 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        
                        Text("\(streakCount) in a row!")
                            .font(.subheadline.weight(.semibold))
                        
                        if isNewRecord {
                            Text("NEW RECORD")
                                .font(.caption2.weight(.black))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.yellow)
                                )
                                .foregroundStyle(.black)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.top, 8)

            Divider()
                .opacity(0.2)

            // Q&A recap
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Question", systemImage: "questionmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(triviaQuestion)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Answer", systemImage: "checkmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)

                    Text(triviaAnswer)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(verdictColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

// MARK: - Record Banner

struct RecordBanner: View {
    let streak: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title3)
                .foregroundStyle(.yellow)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("New Record!")
                    .font(.subheadline.weight(.bold))
                
                Text("\(streak) correct in a row")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThickMaterial)
                .shadow(color: .yellow.opacity(0.3), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Timer Warning Banner

struct TimerWarningBanner: View {
    let seconds: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundStyle(.orange)
            
            Text("\(seconds)s remaining")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.15))
        )
    }
}

// MARK: - Enhanced Confetti

struct EnhancedConfettiView: View {
    @State private var animate = false
    private let colors: [Color] = [.red, .yellow, .blue, .green, .orange, .purple, .pink]
    private let shapes = ["circle.fill", "star.fill", "heart.fill", "triangle.fill"]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<30, id: \.self) { i in
                    Image(systemName: shapes[i % shapes.count])
                        .font(.caption)
                        .foregroundStyle(colors[i % colors.count])
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: animate ? geo.size.height + 50 : -50
                        )
                        .opacity(animate ? 0 : 1)
                        .rotationEffect(.degrees(animate ? Double.random(in: -180...180) : 0))
                        .animation(
                            .easeOut(duration: Double.random(in: 1.2...1.8))
                                .delay(Double(i) * 0.03),
                            value: animate
                        )
                }
            }
            .onAppear {
                animate = true
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Banner Toast (kept for compatibility)

struct BannerToast: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .imageScale(.medium)
                .foregroundStyle(.yellow)
            
            Text(text)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(radius: 8, y: 4)
        .padding(.horizontal)
    }
}

// MARK: - Simple Confetti (kept for compatibility)

struct ConfettiView: View {
    @State private var animate = false
    private let colors: [Color] = [.red, .yellow, .blue, .green, .orange, .purple]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<20, id: \.self) { i in
                    Circle()
                        .fill(colors[i % colors.count])
                        .frame(width: 8, height: 8)
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: animate ? geo.size.height + 40 : -20
                        )
                        .opacity(animate ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.2)
                                .delay(Double(i) * 0.02),
                            value: animate
                        )
                }
            }
            .onAppear {
                animate = true
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
