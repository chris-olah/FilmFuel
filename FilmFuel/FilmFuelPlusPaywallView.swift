//
//  FilmFuelPlusPaywallView.swift
//  FilmFuel
//

import SwiftUI

struct FilmFuelPlusPaywallView: View {
    @EnvironmentObject var store: FilmFuelStore
    @EnvironmentObject var entitlements: FilmFuelEntitlements
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    heroCard
                    perksList
                    smartModeCallout
                    buttonsSection
                    faqSection
                }
                .padding()
            }
            .navigationTitle("FilmFuel+")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Unlock FilmFuel+")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            Text("Turn Discover into your personal movie concierge.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles.tv.fill")
                    .font(.title2)
                Text("Smarter Discover")
                    .font(.headline)
            }

            Text("FilmFuel+ unlocks unlimited Smart Mode and taste-powered shuffles, so every batch feels hand-picked for you.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                Text("Free:")
                    .font(.caption.weight(.semibold))
                Text("2 Smart picks/day")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("FilmFuel+: unlimited")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.accentColor.opacity(0.18), Color(.secondarySystemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
    }

    private var perksList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What you get with FilmFuel+")
                .font(.headline)

            perkRow(
                icon: "sparkles",
                title: "Unlimited Smart Mode",
                text: "No more daily cap – every shuffle can lean into your taste, favorite genres, and hidden gems."
            )

            perkRow(
                icon: "person.2.wave.2.fill",
                title: "Taste-powered Discover",
                text: "Your likes, favorites, and moods shape the feed. The more you use it, the better it gets."
            )

            perkRow(
                icon: "gamecontroller.fill",
                title: "Trivia & future perks",
                text: "Support FilmFuel today and unlock current Plus goodies, plus upcoming trivia & Discover upgrades."
            )

            perkRow(
                icon: "heart.fill",
                title: "Support a solo dev",
                text: "You’re literally helping keep FilmFuel alive and evolving. Thank you. 🙏"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func perkRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var smartModeCallout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.heart.fill")
                    .font(.headline)
                    .foregroundColor(.accentColor)
                Text("Already love Discover?")
                    .font(.subheadline.weight(.semibold))
            }

            Text("FilmFuel+ is the “turn it up” button for the features you’re already using – smarter shuffles, better picks, and no daily limits.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var buttonsSection: some View {
        VStack(spacing: 10) {
            Button {
                // TODO: Wire this to your FilmFuelStore purchase call, e.g.:
                // store.purchasePlus()
            } label: {
                Text("Start FilmFuel+")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Button {
                // TODO: Wire this to your restore purchases call, e.g.:
                // store.restorePurchases()
            } label: {
                Text("Restore purchases")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(10)
            }
        }
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 8)

            Text("FAQ")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("What happens if I don’t upgrade?")
                    .font(.subheadline.weight(.semibold))
                Text("You can keep using FilmFuel for free with 2 Smart Mode sessions per day and all the core features.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Will my current picks change?")
                    .font(.subheadline.weight(.semibold))
                Text("FilmFuel+ doesn’t take anything away – it just levels up Discover, Smart Mode, and taste-driven shuffles.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
