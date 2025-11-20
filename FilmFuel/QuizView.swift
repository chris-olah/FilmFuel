// Commit Test (fixing email address issue)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Daily Quiz

struct QuizView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    @State private var selectedIndex: Int? = nil
    @State private var reveal = false
    @State private var isCorrect = false
    @State private var showShare = false
    @State private var reviewMode = false

    // Confetti state
    @State private var showConfetti = false

    // For answer list animation
    @State private var answersAppeared = false

    // "More trivia" sheet
    @State private var showMoreTriviaSheet = false
    @State private var showMoreButton = false

    // Computed accessors
    private var trivia: TriviaQuestion? { appModel.todayTrivia }
    private var quoteMovie: String { trivia?.movieTitle ?? "Today’s Movie" }
    private var quoteYear: Int { trivia?.year ?? 0 }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                headerSection()

                if let trivia {
                    quizCard(trivia: trivia)
                        .padding(.horizontal)

                    submitButtonSection(trivia: trivia)
                        .padding(.horizontal)

                    resultSection(trivia: trivia)
                        .padding(.horizontal)
                } else {
                    loadingSection()
                }

                // ⬆️ Bigger spacer so "Play More Trivia" sits a bit higher
                Spacer(minLength: 32)
            }

            // Confetti overlay on correct (daily quiz)
            if showConfetti {
                ConfettiView()
                    .transition(.opacity)
            }

            // Toast overlay (quiz-only)
            VStack {
                if appModel.showNewRecordToast {
                    BannerToast(text: "New record: \(appModel.bestCorrectStreak)")
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
                Spacer()
            }
        }
        .onAppear {
            // Make sure trivia is loaded/chosen
            appModel.ensureTodayTrivia()

            if appModel.quizCompletedToday {
                reviewMode = true
                reveal = true
                showMoreButton = true
            }

            // kick off answer animations
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    answersAppeared = true
                }
            }
        }
        // iOS 17-style onChange (no deprecation)
        .onChange(of: reveal) {
            if reveal {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) {
                    showMoreButton = true
                }
            }
        }
        // Share sheet (keep as sheet)
        .sheet(isPresented: $showShare) {
            ShareSheet(activityItems: [
                shareMessage()
            ])
        }
        // Endless trivia -> full-screen cover so it uses whole iPad screen
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
                }
            }
            // No trailing toolbar item – share + stats live in header
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func headerSection() -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Left: title + movie/year
            VStack(alignment: .leading, spacing: 4) {
                Text("Today’s Quiz")
                    .font(.title3.weight(.semibold))

                Text(
                    quoteYear == 0
                    ? quoteMovie
                    : "\(quoteMovie) • \(quoteYear)"
                )
                .font(.callout.weight(.semibold))        // slightly bigger + bolder
                .foregroundStyle(.primary)               // higher contrast
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 8)

            // Center: streak stats (if any)
            if appModel.dailyStreak > 0 || appModel.bestCorrectStreak > 0 {
                HStack(spacing: 6) {
                    if appModel.dailyStreak > 0 {
                        statPill(
                            icon: "flame.fill",
                            label: "\(appModel.dailyStreak)",
                            subtitle: "Daily",
                            color: .orange
                        )
                        .accessibilityLabel("Current daily streak: \(appModel.dailyStreak) days")
                    }

                    if appModel.bestCorrectStreak > 0 {
                        statPill(
                            icon: "trophy.fill",
                            label: "\(appModel.bestCorrectStreak)",
                            subtitle: "Best",
                            color: .yellow
                        )
                        .accessibilityLabel("Best streak: \(appModel.bestCorrectStreak)")
                    }
                }
            }

            // Right: share button
            Button {
                showShare = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .imageScale(.medium)
                    .font(.body.weight(.semibold))
            }
            .accessibilityLabel("Share today’s quiz")
        }
        .padding(.horizontal)
        // Middle ground so it clears status bar / Dynamic Island
        .padding(.top, 24)
    }

    // Stat pill with tiny subtitle (Daily / Best)
    private func statPill(icon: String, label: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .imageScale(.small)
                Text(label)
                    .font(.caption2.weight(.semibold))
            }

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            .ultraThinMaterial,
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    // MARK: - Loading

    @ViewBuilder
    private func loadingSection() -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Fetching today’s quiz…")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                appModel.ensureTodayTrivia()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
    }

    // MARK: - Quiz Card

    @ViewBuilder
    private func quizCard(trivia: TriviaQuestion) -> some View {
        VStack(spacing: 16) {
            // Cleaner card: just the question (movie info is in the header)
            Text(trivia.question)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 12)

            // Answers
            VStack(spacing: 10) {
                ForEach(trivia.options.indices, id: \.self) { i in
                    AnswerRow(
                        text: trivia.options[i],
                        index: i,
                        selectedIndex: selectedIndex,
                        correctIndex: trivia.correctIndex,
                        reveal: reveal,
                        reviewMode: reviewMode
                    ) {
                        guard !reveal, !reviewMode else { return }
                        selectedIndex = i
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        #endif
                    }
                    .opacity(answersAppeared ? 1 : 0)
                    .offset(y: answersAppeared ? 0 : 12)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.85)
                            .delay(Double(i) * 0.04),
                        value: answersAppeared
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Tiny footer hint
            if let extra = trivia.extraInfo, reveal {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb")
                        .imageScale(.small)
                    Text(extra)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
        .padding(.vertical, 8)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .shadow(radius: 4, y: 2)
        .padding(.top, 4)
    }

    // MARK: - Submit Button

    @ViewBuilder
    private func submitButtonSection(trivia: TriviaQuestion) -> some View {
        if !reviewMode && !reveal {
            Button {
                submitSelected(correctIndex: trivia.correctIndex)
            } label: {
                Label("Check Answer", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .controlSize(.large)
            .opacity(selectedIndex == nil ? 0.5 : 1.0)
            .disabled(selectedIndex == nil)
        }
    }

    // MARK: - Result Section

    @ViewBuilder
    private func resultSection(trivia: TriviaQuestion) -> some View {
        if reveal {
            ResultPanel(
                reviewMode: reviewMode,
                isCorrect: reviewMode ? appModel.lastResultWasCorrect : isCorrect,
                triviaQuestion: trivia.question,
                triviaAnswer: safeAnswerText(trivia: trivia),
                movieTitle: quoteMovie,
                movieYear: quoteYear
            )
            .transition(.opacity.combined(with: .move(edge: .bottom)))

            if reviewMode {
                // Short, less cluttered helper text
                Text("New quiz unlocks tomorrow.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }

            // "Play More Trivia" button
            Button {
                showMoreTriviaSheet = true
            } label: {
                Text("Play More Trivia")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .controlSize(.large)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .scaleEffect(showMoreButton ? 1.0 : 0.9)
            .opacity(showMoreButton ? 1.0 : 0.0)
            .shadow(radius: showMoreButton ? 4 : 0, y: showMoreButton ? 2 : 0)
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
        }

        if correct {
            triggerConfetti()
        }

        // Daily quiz affects streaks
        appModel.registerAnswer(correct: correct)
    }

    private func triggerConfetti() {
        showConfetti = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.3)) {
                showConfetti = false
            }
        }
    }

    // MARK: - Share text (constant, short, always Q + A + movie)

    private func shareMessage() -> String {
        let movie = quoteMovie
        let yearPart = quoteYear == 0 ? "" : " (\(quoteYear))"
        let question = trivia?.question ?? "Today’s trivia question"
        let answer = trivia.map { safeAnswerText(trivia: $0) } ?? ""

        var lines: [String] = []

        // Fun + clean top
        lines.append("FilmFuel Trivia 🎬 — \(movie)\(yearPart)")
        lines.append("✨ Q: \(question)")
        if !answer.isEmpty {
            lines.append("🍿 A: \(answer)")
        }

        // Soft promotional footer
        lines.append("")
        lines.append("Play daily trivia & more on FilmFuel!")

        return lines.joined(separator: "\n")
    }

    private func safeAnswerText(trivia: TriviaQuestion) -> String {
        let idx = trivia.correctIndex
        guard idx >= 0 && idx < trivia.options.count else { return "" }
        return trivia.options[idx]
    }
}

// MARK: - Shared Subviews (used by both QuizView & TriviaPlaygroundView)

struct AnswerRow: View {
    let text: String
    let index: Int
    let selectedIndex: Int?
    let correctIndex: Int
    let reveal: Bool
    let reviewMode: Bool
    let onTap: () -> Void

    var isSelected: Bool { selectedIndex == index }
    var isCorrectChoice: Bool { index == correctIndex }

    var body: some View {
        Button(action: {
            guard !reveal, !reviewMode else { return }
            onTap()
        }) {
            HStack(spacing: 10) {
                // Radio / status icon
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
                    } else if isSelected {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(.secondary)
                }

                Text(text)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.92)

                if reviewMode && isCorrectChoice {
                    Text("Answer")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.12))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .scaleEffect(reveal && isCorrectChoice ? 1.02 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: reveal)
        }
        .buttonStyle(ScaledButtonStyle())
        .background(backgroundStyle)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(borderStyle, lineWidth: 1)
        )
        .accessibilityLabel(accessibilityDescription)
    }

    private var backgroundStyle: Color {
        if reviewMode {
            return isCorrectChoice ? Color.green.opacity(0.08) : Color(.secondarySystemBackground)
        }
        if reveal {
            if isCorrectChoice { return Color.green.opacity(0.18) }
            if isSelected { return Color.red.opacity(0.14) }
            return Color(.tertiarySystemFill)
        } else if isSelected {
            return Color(.tertiarySystemFill)
        }
        return Color(.secondarySystemBackground)
    }

    private var borderStyle: Color {
        if reviewMode {
            return isCorrectChoice ? Color.green.opacity(0.35) : Color.secondary.opacity(0.18)
        }
        if reveal {
            if isCorrectChoice { return Color.green.opacity(0.6) }
            if isSelected { return Color.red.opacity(0.5) }
            return Color.secondary.opacity(0.18)
        } else if isSelected {
            return Color.secondary.opacity(0.35)
        }
        return Color.secondary.opacity(0.18)
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

// ButtonStyle for subtle press-scale
struct ScaledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - Result Panel

struct ResultPanel: View {
    let reviewMode: Bool
    let isCorrect: Bool?
    let triviaQuestion: String
    let triviaAnswer: String
    let movieTitle: String
    let movieYear: Int

    private var yearText: String {
        String(movieYear)
    }

    var verdictText: String {
        if let correct = isCorrect {
            return correct ? "Good Answer! 🎯" : "Nice Try! 💭"
        }
        return reviewMode ? "Quiz Locked 🔒" : "Result"
    }

    var verdictColor: Color {
        if let c = isCorrect { return c ? .green : .orange }
        return .secondary
    }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text(verdictText)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(verdictColor)

                Text("From \(movieTitle) (\(yearText))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider().opacity(0.15)

            VStack(alignment: .leading, spacing: 8) {
                Text("Trivia")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(triviaQuestion)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Answer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Text(triviaAnswer)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .shadow(radius: 2, y: 1)
    }
}

// MARK: - Banner Toast

struct BannerToast: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill").imageScale(.medium)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(radius: 8, y: 4)
        .padding(.horizontal)
    }
}

// MARK: - Simple Confetti View

struct ConfettiView: View {
    @State private var animate = false
    private let colors: [Color] = [.red, .yellow, .blue, .green, .orange, .purple]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<20, id: \.self) { i in
                    Circle()
                        .fill(colors[i % colors.count])
                        .frame(width: 6, height: 6)
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
