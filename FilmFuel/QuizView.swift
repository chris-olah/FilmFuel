import SwiftUI

struct QuizView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    @State private var selectedIndex: Int? = nil
    @State private var reveal = false
    @State private var isCorrect = false
    @State private var showShare = false
    @State private var reviewMode = false

    // Computed accessors (lighter for type-checker)
    private var trivia: Trivia { appModel.todayQuote.trivia }
    private var quoteMovie: String { appModel.todayQuote.movie }
    private var quoteYear: Int { appModel.todayQuote.year }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                headerSection()
                questionSection()
                submitButtonSection()
                resultSection()
                Spacer(minLength: 8)
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
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(activityItems: [
                shareMessage(isCorrect: (reviewMode ? (appModel.lastResultWasCorrect ?? false) : isCorrect))
            ])
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { Image(systemName: "chevron.left") }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func headerSection() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today’s Quiz")
                    .font(.title3.weight(.semibold))
                // Year shown without locale commas (e.g., 2005, not 2,005)
                Text(verbatim: "\(quoteMovie) • \(quoteYear)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func questionSection() -> some View {
        VStack(spacing: 16) {
            Text(trivia.question)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 8)

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
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func submitButtonSection() -> some View {
        if !reviewMode && !reveal {
            Button {
                submitSelected(correctIndex: trivia.correctIndex)
            } label: {
                Label("Submit", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .controlSize(.large)
            .padding(.horizontal)
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
                triviaAnswer: trivia.choices[trivia.correctIndex]
            )
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .padding(.horizontal)

            // Only Share button; no Back-to-Home
            HStack(spacing: 12) {
                Button { showShare = true } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
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
        appModel.registerAnswer(correct: correct)
    }

    private func shareMessage(isCorrect: Bool) -> String {
        let q = appModel.todayQuote
        let verdict = isCorrect ? "Good Answer!" : "Nice Try!"
        return "\(verdict) on FilmFuel 🎬\n“\(q.text)” — \(q.movie) (\(String(q.year)))"
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
                Text(text)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.92)

                if !reviewMode {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                } else if isCorrectChoice {
                    Text("Answer")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
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

    var verdictText: String {
        if let correct = isCorrect { return correct ? "Good Answer! 🎯" : "Nice Try! 💭" }
        return reviewMode ? "Quiz Locked 🔒" : "Result"
    }

    var verdictColor: Color {
        if let c = isCorrect { return c ? .green : .orange }
        return .secondary
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(verdictText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(verdictColor)

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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
            Text(text).font(.subheadline.weight(.semibold)).lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(radius: 8, y: 4)
        .padding(.horizontal)
    }
}
