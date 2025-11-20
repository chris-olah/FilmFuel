//
//  TriviaPlaygroundView.swift
//  FilmFuel
//
//  Created by Chris Olah on 11/17/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Unlimited Trivia View (More Trivia + Session Summary)

struct TriviaPlaygroundView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    // Persisted all-time best streak for unlimited mode
    @AppStorage("ff.unlimited.bestStreak")
    private var bestUnlimitedStreak: Int = 0

    // Current question state
    @State private var currentQuestion: TriviaQuestion?
    @State private var selectedIndex: Int? = nil
    @State private var reveal = false
    @State private var isCorrect = false
    @State private var answersAppeared = false
    @State private var showConfetti = false

    // Session stats (for this run)
    @State private var questionsAnswered: Int = 0
    @State private var correctAnswers: Int = 0
    @State private var sessionStreak: Int = 0
    @State private var bestSessionStreak: Int = 0

    // Session summary alert
    @State private var showSummaryAlert: Bool = false

    // Streak milestone banner
    @State private var milestoneMessage: String? = nil

    // Card bounce animation
    @State private var cardBounce: Bool = false

    // MARK: - Derived values

    private var accuracyPercent: Int {
        guard questionsAnswered > 0 else { return 0 }
        return Int((Double(correctAnswers) / Double(questionsAnswered)) * 100)
    }

    private var accuracyLine: String {
        "Accuracy: \(accuracyPercent)%."
    }

    // Central accent color – later can be swapped per theme / premium
    private var accentColor: Color {
        Color.orange   // film-y, warm, friendly; easy to brand later
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Soft vertical gradient background
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.secondarySystemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 10) {
                    // Static top header card + stats
                    header

                    if let q = currentQuestion {

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
                                Label(
                                    isCorrect ? "Keep it going" : "Try another",
                                    systemImage: isCorrect
                                        ? "arrow.right.circle.fill"
                                        : "arrow.uturn.right.circle"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .padding(.horizontal)
                        }

                        // Stats bar tucked right under the main button/result area
                        sessionSummaryStrip
                            .padding(.top, 6)

                    } else {
                        VStack(spacing: 10) {
                            Text("No trivia available yet.")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            // Still show the lower strip so layout stays consistent
                            sessionSummaryStrip
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 24)  // shifted everything up so strip sits higher

                // Confetti overlay when correct
                if showConfetti {
                    ConfettiView()
                        .transition(.opacity)
                }

                // Streak milestone banner
                if let message = milestoneMessage {
                    VStack {
                        Text(message)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(.systemBackground))
                                    .shadow(radius: 4, y: 2)
                            )
                            .padding(.top, 16)
                            .scaleEffect(1.03)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.6),
                                value: message
                            )

                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onAppear {
                // Make sure the triviaBank is populated from all packs
                appModel.loadTriviaIfNeeded()

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
                // No principal title – the big card is the “real” title
            }
            .alert("Wrap up this session?", isPresented: $showSummaryAlert) {
                Button("Keep Playing", role: .cancel) {}

                Button("End Session", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text(
                    "Questions: \(questionsAnswered) • Correct: \(correctAnswers)\nBest session: \(bestSessionStreak) • All-time best: \(bestUnlimitedStreak)\n\(accuracyLine)"
                )
            }
        }
    }

    // MARK: - Header (Static Top Card + Stats)

    private var header: some View {
        VStack(spacing: 6) {
            // Mode card – slightly shorter vertically
            VStack(spacing: 3) {
                Text("More Trivia")
                    .font(.title3.weight(.semibold))

                Text("Endless warm-up mode")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6) // trimmed to save a bit of height
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.96))
                    .shadow(radius: 4, y: 2)
            )
            .padding(.horizontal)

            if questionsAnswered > 0 || bestUnlimitedStreak > 0 {
                HStack(spacing: 8) {
                    StatPill(
                        icon: "number.square",
                        title: "Answered",
                        value: "\(questionsAnswered)"
                    )
                    StatPill(
                        icon: "checkmark.circle",
                        title: "Correct",
                        value: "\(correctAnswers)"
                    )
                    StatPill(
                        icon: "target",
                        title: "Accuracy",
                        value: "\(accuracyPercent)%"
                    )
                    StatPill(
                        icon: "flame.fill",
                        title: "Best",
                        value: "\(bestUnlimitedStreak)"
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Session summary strip (bottom HUD)

    private var sessionSummaryStrip: some View {
        Group {
            if questionsAnswered > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "gamecontroller.fill")
                        .imageScale(.small)

                    Text("\(questionsAnswered) Q • \(correctAnswers) correct • \(accuracyPercent)%")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 8)

                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .imageScale(.small)
                        Text("Streak \(sessionStreak)")
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Button {
                        resetSessionStats()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .imageScale(.small)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Reset session stats")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.95))
                        .shadow(radius: 4, y: 2)
                )
                .frame(maxWidth: 320)        // narrower pill
                .frame(maxWidth: .infinity)  // centered

            } else {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .imageScale(.small)

                    Text("Answer a question to start your stats.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.95))
                        .shadow(radius: 2, y: 1)
                )
                .frame(maxWidth: 320)        // narrower pill
                .frame(maxWidth: .infinity)  // centered
            }
        }
    }

    // MARK: - Trivia card

    @ViewBuilder
    private func quizCard(trivia: TriviaQuestion) -> some View {
        VStack(spacing: 12) {

            // Top HUD: Question number + movie
            VStack(spacing: 2) {
                Text("Question \(questionsAnswered + 1)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)

                Text(trivia.movieTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }

            // Question – keeps height under control but still readable
            Text(trivia.question)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(3)                // up to 3 lines
                .minimumScaleFactor(0.8)     // shrinks slightly if needed
                .padding(.horizontal)
                .padding(.top, 4)

            VStack(spacing: 8) {
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
                    .offset(y: answersAppeared ? 0 : 10)
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.85)
                            .delay(Double(i) * 0.04),
                        value: answersAppeared
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
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
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .padding(.horizontal)
    }

    // MARK: - Logic

    private func loadNextQuestion() {
        // Use AppModel's queue-style helper so we don't repeat questions
        guard let candidate = appModel.nextEndlessTriviaQuestion() else { return }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
            currentQuestion = candidate
            selectedIndex = nil
            reveal = false
            isCorrect = false
            answersAppeared = false
            cardBounce = false
        }

        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                answersAppeared = true
                cardBounce = true
            }
        }
    }

    private func submitSelected(correctIndex: Int) {
        guard let sel = selectedIndex, !reveal else { return }
        let correct = (sel == correctIndex)
        isCorrect = correct

        // Update stats
        questionsAnswered += 1
        
        // Stats: track endless trivia answers
        StatsManager.shared.trackEndlessTriviaAnswer(correct: correct)


        // 🎯 Only treat certain session milestones as "review-worthy" events.
        // RateManager still enforces global rules (days since install, cooldown, etc.).
        let milestoneCounts = [5, 10, 20, 30]
        if milestoneCounts.contains(questionsAnswered) {
            RateManager.shared.trackTriviaCompleted()
        }

        if correct {
            correctAnswers += 1
            sessionStreak += 1
            bestSessionStreak = max(bestSessionStreak, sessionStreak)
            bestUnlimitedStreak = max(bestUnlimitedStreak, sessionStreak)

            // Milestones
            if [5, 10, 20].contains(sessionStreak) {
                milestoneMessage = "🔥 \(sessionStreak)-answer streak!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        milestoneMessage = nil
                    }
                }
            }

        } else {
            sessionStreak = 0
        }

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(
            correct ? .success : .error
        )
        #endif

        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
            reveal = true
        }

        if correct {
            triggerConfetti()
        }

        // Unlimited mode does NOT call appModel.registerAnswer
    }

    private func triggerConfetti() {
        showConfetti = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showConfetti = false
            }
        }
    }

    private func resetSessionStats() {
        questionsAnswered = 0
        correctAnswers = 0
        sessionStreak = 0
        bestSessionStreak = 0
        milestoneMessage = nil
    }

    private func safeAnswerText(trivia: TriviaQuestion) -> String {
        let idx = trivia.correctIndex
        guard idx >= 0 && idx < trivia.options.count else { return "" }
        return trivia.options[idx]
    }
}

// MARK: - Stat Pill

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
