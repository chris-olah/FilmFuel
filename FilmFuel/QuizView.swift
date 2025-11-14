import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

    // Computed accessors
    private var trivia: Trivia { appModel.todayQuote.trivia }
    private var quoteMovie: String { appModel.todayQuote.movie }
    private var quoteYear: Int { appModel.todayQuote.year }

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

                quizCard()
                    .padding(.horizontal)

                submitButtonSection()
                    .padding(.horizontal)

                resultSection()
                    .padding(.horizontal)

                Spacer(minLength: 8)
            }

            // Confetti overlay on correct
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
                Text("Today’s Quiz")
                    .font(.title3.weight(.semibold))

                // Ensure no comma formatting in year
                Text("\(quoteMovie) • \(String(quoteYear))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
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

    @ViewBuilder
    private func quizCard() -> some View {
        VStack(spacing: 16) {
            // Question
            Text(trivia.question)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 8)

            // Answers
            VStack(spacing: 10) {
                ForEach(trivia.choices.indices, id: \.self) { i in
                    AnswerRow(
                        text: trivia.choices[i],
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
                    // Springy appear animation, slightly staggered
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
    }

    @ViewBuilder
    private func submitButtonSection() -> some View {
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
    private func resultSection() -> some View {
        if reveal {
            ResultPanel(
                reviewMode: reviewMode,
                isCorrect: reviewMode ? appModel.lastResultWasCorrect : isCorrect,
                triviaQuestion: trivia.question,
                triviaAnswer: safeAnswerText(),
                movieTitle: quoteMovie,
                movieYear: quoteYear
            )
            .transition(.opacity.combined(with: .move(edge: .bottom)))

            // Only Share button; no Back-to-Home
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

    // New share message: trivia question + answer + movie/year
    private func shareMessage(isCorrect: Bool) -> String {
        let verdict = isCorrect ? "I got it right!" : "I missed today’s trivia!"
        let question = trivia.question
        let answer = safeAnswerText()
        let movie = quoteMovie
        let year = String(quoteYear)

        return """
        \(verdict) on FilmFuel 🎬
        Trivia: \(question)
        Answer: \(answer)
        From: \(movie) (\(year))
        """
    }

    private func safeAnswerText() -> String {
        let idx = trivia.correctIndex
        guard idx >= 0 && idx < trivia.choices.count else { return "" }
        return trivia.choices[idx]
    }
}

// MARK: - Subviews

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

                // Ensure no comma in year formatting
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
