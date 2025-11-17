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
