//
//  StatsView.swift
//  FilmFuel
//
//  Created by Chris Olah on 11/20/25.
//

import SwiftUI

struct StatsView: View {
    private let stats = StatsManager.shared

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }

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
            .ignoresSafeArea()

            List {
                // Overall
                Section("Overview") {
                    StatRow(
                        icon: "gamecontroller.fill",
                        title: "Total trivia questions answered",
                        value: "\(stats.totalTriviaQuestionsAnswered)"
                    )

                    StatRow(
                        icon: "checkmark.circle.fill",
                        title: "Total correct answers",
                        value: "\(stats.totalTriviaCorrect)"
                    )

                    StatRow(
                        icon: "target",
                        title: "Overall accuracy",
                        value: "\(stats.overallAccuracyPercent)%"
                    )
                }

                // Trivia breakdown
                Section("Trivia Modes") {
                    StatRow(
                        icon: "calendar",
                        title: "Daily trivia sessions completed",
                        value: "\(stats.dailyTriviaSessionsCompleted)"
                    )

                    StatRow(
                        icon: "infinity",
                        title: "Endless trivia sessions completed",
                        value: "\(stats.endlessTriviaSessionsCompleted)"
                    )
                }

                // Discover-specific stats
                Section("Discover") {
                    StatRow(
                        icon: "rectangle.on.rectangle.angled",
                        title: "Discover cards viewed",
                        value: "\(stats.discoverCardsViewed)"
                    )
                }

                // Library
                Section("Library") {
                    StatRow(
                        icon: "heart.fill",
                        title: "Saved quotes screen opened",
                        value: "\(stats.favoritesOpenedCount)"
                    )
                }

                // App usage
                Section("App Usage") {
                    StatRow(
                        icon: "flame",
                        title: "App launches",
                        value: "\(stats.appLaunchCount)"
                    )

                    if let first = stats.firstLaunchDate {
                        StatRow(
                            icon: "clock.arrow.circlepath",
                            title: "First used",
                            value: dateFormatter.string(from: first)
                        )
                    }

                    if let last = stats.lastLaunchDate {
                        StatRow(
                            icon: "clock",
                            title: "Last opened",
                            value: dateFormatter.string(from: last)
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Stats")
        }
    }
}

// MARK: - Small reusable row

private struct StatRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .imageScale(.medium)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
