//
//  MultipleChoiceQuestionView.swift
//  FilmFuel
//
//  Created by Chris Olah on 11/9/25.
//

import SwiftUI

struct MultipleChoiceQuestionView: View {
    struct Choice: Identifiable {
        let id: Int
        let text: String
    }

    let questionText: String
    let choices: [Choice]          // four choices, id = 0..3
    let correctIndex: Int
    var onSubmit: (_ selectedIndex: Int, _ isCorrect: Bool) -> Void = { _,_ in }

    @State private var selectedIndex: Int? = nil
    @State private var submitted = false

    var body: some View {
        VStack(spacing: 20) {
            Text(questionText)
                .font(.title3).bold()
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Choices
            VStack(spacing: 12) {
                ForEach(choices) { choice in
                    choiceRow(choice)
                }
            }
            .padding(.horizontal)

            // Submit / Next
            Button(action: handlePrimaryTap) {
                Text(primaryButtonTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canTapPrimary)
            .padding(.horizontal)

            // Feedback (after submit)
            if submitted, let selectedIndex {
                let isCorrect = selectedIndex == correctIndex
                Text(isCorrect ? "Correct! 🎉" : "Not quite.")
                    .font(.subheadline).bold()
                    .padding(.top, 6)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: submitted)
    }

    // MARK: - Views

    @ViewBuilder
    private func choiceRow(_ choice: Choice) -> some View {
        let isSelected = selectedIndex == choice.id
        let isCorrectChoice = submitted && choice.id == correctIndex
        let isWrongSelected = submitted && isSelected && choice.id != correctIndex

        Button {
            if !submitted { selectedIndex = choice.id }
        } label: {
            HStack(spacing: 12) {
                // Letter badge A/B/C/D
                Text(letter(for: choice.id))
                    .font(.headline).monospaced()
                    .frame(width: 28, height: 28)
                    .background(Circle().strokeBorder(lineWidth: 1.2))
                Text(choice.text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                Spacer()
                // Check/X after submit
                if isCorrectChoice { Image(systemName: "checkmark.circle.fill") }
                else if isWrongSelected { Image(systemName: "xmark.circle.fill") }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(borderColor(isSelected: isSelected,
                                              correct: isCorrectChoice,
                                              wrong: isWrongSelected),
                                  lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(letter(for: choice.id)). \(choice.text)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Helpers

    private var canTapPrimary: Bool {
        if submitted { return true }          // “Next” always enabled
        return selectedIndex != nil           // “Submit” requires a selection
    }

    private var primaryButtonTitle: String {
        submitted ? "Next" : "Submit"
    }

    private func handlePrimaryTap() {
        if !submitted {
            if let sel = selectedIndex {
                let correct = sel == correctIndex
                onSubmit(sel, correct)
                submitted = true
                UIImpactFeedbackGenerator(style: correct ? .rigid : .light).impactOccurred()
            }
        } else {
            // Parent should advance to next question/day
            // You can also send another callback if needed.
        }
    }

    private func borderColor(isSelected: Bool, correct: Bool, wrong: Bool) -> Color {
        if correct { return .green }
        if wrong { return .red }
        return isSelected ? .primary : .secondary.opacity(0.4)
    }

    private func letter(for index: Int) -> String {
        ["A","B","C","D"][index]
    }
}
