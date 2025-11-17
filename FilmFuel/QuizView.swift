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

    // Computed accessors
    private var trivia: TriviaQuestion? { appModel.todayTrivia }
    private var quoteMovie: String { trivia?.movieTitle ?? "Today’s Movie" }
    private var quoteYear: Int { trivia?.year ?? 0 }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top, endPoint: .bottom
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
                    Text("Loading today’s trivia…")
                        .foregroundStyle(.secondary)
                        .padding()
                }

                // "More Trivia" entry point
                Button {
                    showMoreTriviaSheet = true
                } label: {
                    Label("Play More Trivia", systemImage: "infinity")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal)

                Spacer(minLength: 8)
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
            }

            // kick off answer animations
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    answersAppeared = true
                }
            }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(activityItems: [
                shareMessage(
                    isCorrect: reviewMode
                        ? (appModel.lastResultWasCorrect ?? false)
                        : isCorrect
                )
            ])
        }
        .sheet(isPresented: $showMoreTriviaSheet) {
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
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func headerSection() -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Today’s Quiz")
                        .font(.title3.weight(.semibold))

                    if let trivia {
                        difficultyPill(trivia.difficulty)
                    }
                }

                Text(quoteYear == 0
                     ? quoteMovie
                     : "\(quoteMovie) • \(quoteYear)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Streak info
                HStack(spacing: 8) {
                    Label {
                        Text("\(appModel.dailyStreak) day streak")
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)

                    if appModel.bestCorrectStreak > 0 {
                        Text("Best: \(appModel.bestCorrectStreak)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Small status pill: Live vs Review
            Text(reviewMode ? "Review" : "Live")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(
                        reviewMode
                        ? Color.orange.opacity(0.18)
                        : Color.green.opacity(0.18)
                    )
                )
                .foregroundStyle(reviewMode ? .orange : .green)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func difficultyPill(_ difficulty: String) -> some View {
        let label = difficulty.capitalized
        let color: Color
        switch difficulty.lowercased() {
        case "easy":   color = .green
        case "medium": color = .orange
        case "hard":   color = .red
        default:       color = .gray
        }

        return Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func quizCard(trivia: TriviaQuestion) -> some View {
        VStack(spacing: 16) {
            // Movie / meta
            VStack(spacing: 4) {
                Text(trivia.movieTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    if trivia.year > 0 {
                        Label("\(trivia.year)", systemImage: "calendar")
                    }
                    Label(trivia.genre, systemImage: "film")
                }
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.9))
            }
            .padding(.top, 8)

            // Question
            Text(trivia.question)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

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

            HStack(spacing: 12) {
                Button { showShare = true } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
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

    private func shareMessage(isCorrect: Bool) -> String {
        let verdict = isCorrect ? "I got it right!" : "I missed today’s trivia!"
        let question = trivia?.question ?? ""
        let answer = trivia.map { safeAnswerText(trivia: $0) } ?? ""
        let movie = quoteMovie
        let yearPart = quoteYear == 0 ? "" : " (\(quoteYear))"

        return """
        \(verdict) on FilmFuel 🎬
        Trivia: \(question)
        Answer: \(answer)
        From: \(movie)\(yearPart)
        """
    }

    private func safeAnswerText(trivia: TriviaQuestion) -> String {
        let idx = trivia.correctIndex
        guard idx >= 0 && idx < trivia.options.count else { return "" }
        return trivia.options[idx]
    }
}

// MARK: - Unlimited Trivia View (More Trivia + Session Summary)

struct TriviaPlaygroundView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    @State private var currentQuestion: TriviaQuestion?
    @State private var selectedIndex: Int? = nil
    @State private var reveal = false
    @State private var isCorrect = false
    @State private var answersAppeared = false
    @State private var showConfetti = false

    // Session stats
    @State private var questionsAnswered: Int = 0
    @State private var correctAnswers: Int = 0
    @State private var sessionStreak: Int = 0
    @State private var bestSessionStreak: Int = 0

    // Session summary alert
    @State private var showSummaryAlert: Bool = false

    private var accuracyLine: String {
        guard questionsAnswered > 0 else { return "Accuracy: 0%." }
        let accuracy = Int((Double(correctAnswers) / Double(questionsAnswered)) * 100)
        return "Accuracy: \(accuracy)%."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    header

                    if let q = currentQuestion {
                        quizCard(trivia: q)

                        if !reveal {
                            Button {
                                submitSelected(correctIndex: q.correctIndex)
                            } label: {
                                Label("Check Answer", systemImage: "checkmark.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.black)
                            .controlSize(.large)
                            .opacity(selectedIndex == nil ? 0.5 : 1.0)
                            .disabled(selectedIndex == nil)
                            .padding(.horizontal)
                        } else {
                            ResultPanel(
                                reviewMode: false,
                                isCorrect: isCorrect,
                                triviaQuestion: q.question,
                                triviaAnswer: safeAnswerText(trivia: q),
                                movieTitle: q.movieTitle,
                                movieYear: q.year
                            )
                            .padding(.horizontal)

                            Button {
                                loadNextQuestion()
                            } label: {
                                Label("Next Question", systemImage: "arrow.right.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .padding(.horizontal)
                        }
                    } else {
                        Text("No trivia available yet.")
                            .foregroundStyle(.secondary)
                            .padding()
                    }

                    Spacer(minLength: 8)
                }

                if showConfetti {
                    ConfettiView()
                        .transition(.opacity)
                }
            }
            .onAppear {
                if currentQuestion == nil {
                    loadNextQuestion()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if questionsAnswered > 0 {
                            showSummaryAlert = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .imageScale(.medium)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("More Trivia")
                        .font(.headline)
                }
            }
            .alert("End Session?", isPresented: $showSummaryAlert) {
                Button("Keep Playing", role: .cancel) { }

                Button("End Session", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("""
                You answered \(questionsAnswered) question\(questionsAnswered == 1 ? "" : "s").
                Correct: \(correctAnswers) • Best streak: \(bestSessionStreak)
                \(accuracyLine)
                """)
            }
        }
    }

    // MARK: - Header with stats

    private var header: some View {
        VStack(spacing: 8) {
            Text("More Trivia")
                .font(.title3.weight(.semibold))

            Text("Keep playing as long as you like — this mode doesn’t affect your daily streak.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if questionsAnswered > 0 {
                HStack(spacing: 12) {
                    Label {
                        Text("\(questionsAnswered) answered")
                    } icon: {
                        Image(systemName: "number.square")
                    }

                    Label {
                        Text("\(correctAnswers) correct")
                    } icon: {
                        Image(systemName: "checkmark.circle")
                    }

                    Label {
                        Text("Streak \(sessionStreak)")
                    } icon: {
                        Image(systemName: "flame.fill")
                    }

                    if bestSessionStreak > 0 {
                        Text("Best \(bestSessionStreak)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Card

    @ViewBuilder
    private func quizCard(trivia: TriviaQuestion) -> some View {
        VStack(spacing: 16) {
            Text(trivia.movieTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(trivia.question)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 4)

            VStack(spacing: 10) {
                ForEach(trivia.options.indices, id: \.self) { i in
                    AnswerRow(
                        text: trivia.options[i],
                        index: i,
                        selectedIndex: selectedIndex,
                        correctIndex: trivia.correctIndex,
                        reveal: reveal,
                        reviewMode: false
                    ) {
                        guard !reveal else { return }
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
            .padding(.bottom, 12)
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
        .padding(.horizontal)
    }

    // MARK: - Logic

    private func loadNextQuestion() {
        let pool = appModel.triviaBank
        guard !pool.isEmpty else { return }

        var candidate = pool.randomElement()!

        if let current = currentQuestion, pool.count > 1 {
            // Avoid repeating the same question back-to-back
            var attempts = 0
            while candidate.id == current.id && attempts < 10 {
                candidate = pool.randomElement()!
                attempts += 1
            }
        }

        currentQuestion = candidate
        selectedIndex = nil
        reveal = false
        isCorrect = false
        answersAppeared = false

        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                answersAppeared = true
            }
        }
    }

    private func submitSelected(correctIndex: Int) {
        guard let sel = selectedIndex, !reveal else { return }
        let correct = (sel == correctIndex)
        isCorrect = correct

        // Update session stats
        questionsAnswered += 1
        if correct {
            correctAnswers += 1
            sessionStreak += 1
            bestSessionStreak = max(bestSessionStreak, sessionStreak)
        } else {
            sessionStreak = 0
        }

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
        #endif

        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
            reveal = true
        }

        if correct {
            triggerConfetti()
        }

        // NOTE: Unlimited mode does NOT call appModel.registerAnswer,
        // so it doesn't affect the daily streak or lock your daily quiz.
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

// MARK: - Shared Subviews

private struct AnswerRow: View {
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
        }
        .buttonStyle(.plain)
        .background(backgroundStyle)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(borderStyle, lineWidth: 1)
        )
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
}

private struct ResultPanel: View {
    let reviewMode: Bool
    let isCorrect: Bool?
    let triviaQuestion: String
    let triviaAnswer: String
    let movieTitle: String
    let movieYear: Int

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
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text(verdictText)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(verdictColor)

                Text("Today’s question from \(movieTitle) (\(String(movieYear)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider().opacity(0.15)

            VStack(alignment: .leading, spacing: 10) {
                Text("Trivia")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(triviaQuestion)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Answer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)

                Text(triviaAnswer)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .shadow(radius: 4, y: 2)
    }
}

private struct BannerToast: View {
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

private struct ConfettiView: View {
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
