//
//  TasteOnboardingView.swift
//  FilmFuel
//

import SwiftUI

struct TasteOnboardingView: View {
    @Binding var isPresented: Bool

    /// Called when the user finishes or skips:
    /// - genres: selected TMDB genre IDs (can be empty)
    /// - preferredMood: optional MovieMood “vibe” (can be nil)
    var onComplete: (_ genres: [Int], _ preferredMood: MovieMood?) -> Void

    @State private var selectedGenres: Set<Int> = []
    @State private var selectedMood: MovieMood? = nil

    private let genreOptions: [(id: Int, name: String)] = [
        (28, "Action"), (12, "Adventure"), (16, "Animation"), (35, "Comedy"),
        (80, "Crime"), (99, "Documentary"), (18, "Drama"), (10751, "Family"),
        (14, "Fantasy"), (27, "Horror"), (10402, "Music"), (9648, "Mystery"),
        (10749, "Romance"), (878, "Sci-Fi"), (53, "Thriller"), (10752, "War"), (37, "Western")
    ]

    /// A few vibe options mapped to your existing MovieMood
    private let moodOptions: [MovieMood] = [
        .feelGood,   // “Happy / uplifting”
        .cozy,       // “Cozy night in”
        .adrenaline, // “Intense / thrilling”
        .spooky,     // “Spooky”
        .any         // “I’m open to anything”
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dial in your taste")
                        .font(.title2.weight(.bold))

                    Text("Pick a few genres and a starting vibe so FilmFuel can shape better “For You” picks.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)

                // Genres grid
                Text("Which genres do you usually enjoy?")
                    .font(.subheadline.weight(.semibold))

                ScrollView {
                    LazyVGrid(
                        columns: [.init(.adaptive(minimum: 100), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(genreOptions, id: \.id) { option in
                            let isSelected = selectedGenres.contains(option.id)

                            Button {
                                if isSelected {
                                    selectedGenres.remove(option.id)
                                } else {
                                    selectedGenres.insert(option.id)
                                }
                            } label: {
                                Text(option.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        isSelected
                                        ? Color.accentColor
                                        : Color(.secondarySystemBackground)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                // Vibe / mood chips
                VStack(alignment: .leading, spacing: 8) {
                    Text("What’s your go-to vibe?")
                        .font(.subheadline.weight(.semibold))

                    Text("Optional, but helps us tune your first batch.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(moodOptions) { mood in
                                let isSelected = (selectedMood == mood)

                                Button {
                                    if isSelected {
                                        selectedMood = nil
                                    } else {
                                        selectedMood = mood
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(labelForMood(mood))
                                            .font(.caption.weight(.semibold))
                                    }
                                    .padding(.vertical, 7)
                                    .padding(.horizontal, 12)
                                    .background(
                                        isSelected
                                        ? Color.accentColor.opacity(0.18)
                                        : Color(.secondarySystemBackground)
                                    )
                                    .foregroundColor(
                                        isSelected ? .accentColor : .primary
                                    )
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer()

                // Primary + Skip buttons
                VStack(spacing: 8) {
                    Button {
                        onComplete(Array(selectedGenres), selectedMood)
                        isPresented = false
                    } label: {
                        Text(selectedGenres.isEmpty ? "Continue without picking" : "Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        onComplete([], nil)
                        isPresented = false
                    } label: {
                        Text("Skip for now")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }
            }
            .padding()
            .navigationTitle("Your Taste")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func labelForMood(_ mood: MovieMood) -> String {
        switch mood {
        case .feelGood:   return "Happy / feel-good"
        case .cozy:       return "Cozy night in"
        case .adrenaline: return "Intense / thrilling"
        case .spooky:     return "Spooky"
        case .nostalgic:  return "Nostalgic"
        case .mindBend:   return "Mind-bending"
        case .dateNight:  return "Date night"
        case .any:        return "Surprise me"
        }
    }
}
