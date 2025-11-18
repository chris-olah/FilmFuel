//
//  OnboardingView.swift
//  FilmFuel
//
//  Created by Chris Olah on 11/18/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("ff.hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    private struct Page: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
    }

    // MARK: - Copy + icons tuned for FilmFuel
    private let pages: [Page] = [
        Page(
            icon: "film.fill",
            title: "Daily Cinematic Fuel",
            subtitle: "Wake up to a fresh movie quote every day. Quick hit of motivation, nostalgia, or pure chaos."
        ),
        Page(
            icon: "popcorn.fill",
            title: "Quiz Your Movie Brain",
            subtitle: "Lock in your answer on today’s trivia and see how long you can keep your streak alive."
        ),
        Page(
            icon: "sparkles",
            title: "Discover Films Worth Watching",
            subtitle: "Scroll through hand-picked movies, save favorites, and quietly build a watchlist you’ll actually use."
        )
    ]

    @State private var currentIndex: Int = 0

    var body: some View {
        ZStack {
            // MARK: - Cinematic background
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.10, green: 0.05, blue: 0.15),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Soft vignette overlay
            RadialGradient(
                colors: [
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.0)
                ],
                center: .top,
                startRadius: 0,
                endRadius: 500
            )
            .blendMode(.multiply)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Top bar / logo
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FILMFUEL")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .tracking(4)
                            .foregroundColor(.white.opacity(0.9))

                        Text("Daily movie energy")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    Button("Skip") {
                        completeOnboarding()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                Spacer(minLength: 0)

                // MARK: - Glassmorphism card
                TabView(selection: $currentIndex) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        ZStack {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.45), radius: 26, x: 0, y: 16)

                            VStack(spacing: 24) {
                                // Icon with subtle spotlight
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.orange.opacity(0.4),
                                                    Color.red.opacity(0.4)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 96, height: 96)
                                        .blur(radius: 6)
                                        .opacity(0.6)

                                    Circle()
                                        .fill(Color.black.opacity(0.75))
                                        .frame(width: 96, height: 96)

                                    Image(systemName: page.icon)
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(.top, 24)

                                VStack(spacing: 8) {
                                    Text(page.title)
                                        .font(.title2.weight(.semibold))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.white)

                                    Text(page.subtitle)
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.75))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)
                                }

                                Spacer(minLength: 16)

                                // Tiny hint line
                                Text("Swipe to continue")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.55))
                                    .padding(.bottom, 20)
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .tag(index)
                        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: currentIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: 460)

                Spacer()

                // MARK: - Page indicators + primary CTA
                VStack(spacing: 18) {
                    // Custom page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { idx in
                            Capsule()
                                .fill(
                                    idx == currentIndex
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: [Color.orange, Color.red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                      )
                                    : AnyShapeStyle(
                                        Color.white.opacity(0.25)
                                      )
                                )
                                .frame(width: idx == currentIndex ? 26 : 8, height: 4)
                                .animation(.easeInOut(duration: 0.22), value: currentIndex)
                        }
                    }
                    .padding(.horizontal, 24)

                    // "Ticket" style CTA button
                    Button(action: handlePrimaryButton) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange, Color.red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: Color.red.opacity(0.6), radius: 18, x: 0, y: 10)

                            HStack(spacing: 10) {
                                Image(systemName: "ticket.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .opacity(0.9)

                                Text(currentIndex == pages.count - 1 ? "Start Fueling" : "Next")
                                    .font(.headline.weight(.semibold))

                                Spacer(minLength: 0)

                                if currentIndex == pages.count - 1 {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .opacity(0.9)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                        }
                        .frame(height: 52)
                    }
                    .padding(.horizontal, 24)

                    Button(action: {
                        completeOnboarding()
                    }) {
                        Text("Maybe later")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .padding(.bottom, 26)
                }
            }
        }
    }

    // MARK: - Actions

    private func handlePrimaryButton() {
        if currentIndex < pages.count - 1 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                currentIndex += 1
            }
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        hasSeenOnboarding = true
        dismiss()
    }
}

// MARK: - Preview

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OnboardingView()
                .environment(\.colorScheme, .dark)

            OnboardingView()
                .environment(\.colorScheme, .light)
        }
    }
}
