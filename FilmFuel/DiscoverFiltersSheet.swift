//
//  DiscoverFiltersSheet.swift
//  FilmFuel
//

import SwiftUI

struct DiscoverFiltersSheet: View {
    @Binding var filters: DiscoverFilters
    @Environment(\.dismiss) private var dismiss

    /// FilmFuel+ status (from entitlements)
    let isPremiumUnlocked: Bool

    /// Called when the user taps an upgrade CTA in the sheet
    let onUpgradeTapped: (() -> Void)?

    // Common TMDB genre IDs
    private struct GenreOption: Identifiable {
        let id: Int        // TMDB genre id
        let name: String
    }

    // Source: TMDB genres
    private let genreOptions: [GenreOption] = [
        .init(id: 28,    name: "Action"),
        .init(id: 12,    name: "Adventure"),
        .init(id: 16,    name: "Animation"),
        .init(id: 35,    name: "Comedy"),
        .init(id: 80,    name: "Crime"),
        .init(id: 99,    name: "Documentary"),
        .init(id: 18,    name: "Drama"),
        .init(id: 10751, name: "Family"),
        .init(id: 14,    name: "Fantasy"),
        .init(id: 27,    name: "Horror"),
        .init(id: 10402, name: "Music"),
        .init(id: 9648,  name: "Mystery"),
        .init(id: 10749, name: "Romance"),
        .init(id: 878,   name: "Sci-Fi"),
        .init(id: 10770, name: "TV Movie"),
        .init(id: 53,    name: "Thriller"),
        .init(id: 10752, name: "War"),
        .init(id: 37,    name: "Western")
    ]

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Sort

                Section(header: Text("Sort By")) {
                    Picker("Sort By", selection: $filters.sort) {
                        ForEach(DiscoverSort.allCases) { sort in
                            Text(sort.label).tag(sort)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: - Rating

                Section(header: Text("Minimum Rating")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { filters.minRating },
                                set: { filters.minRating = $0 }
                            ),
                            in: 0...10,
                            step: 0.5
                        )
                        HStack {
                            Text("0")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "Current: %.1f", filters.minRating))
                                .font(.caption)
                            Spacer()
                            Text("10")
                                .font(.caption)
                        }
                    }
                }

                // MARK: - Year

                Section(header: Text("Year Range")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("From")
                                .font(.caption)
                            TextField("Min year", text: Binding(
                                get: { filters.minYear.map(String.init) ?? "" },
                                set: { filters.minYear = Int($0) }
                            ))
                            .keyboardType(.numberPad)
                        }

                        Spacer()

                        VStack(alignment: .leading) {
                            Text("To")
                                .font(.caption)
                            TextField("Max year", text: Binding(
                                get: { filters.maxYear.map(String.init) ?? "" },
                                set: { filters.maxYear = Int($0) }
                            ))
                            .keyboardType(.numberPad)
                        }
                    }
                }

                // MARK: - Genres

                Section(header: Text("Genres")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(genreOptions) { option in
                                genreChip(option)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if !filters.selectedGenreIDs.isEmpty {
                        Text(selectedGenresDescription)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: - Streaming Services

                Section(header: Text("Streaming Services")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(StreamingService.allCases, id: \.self) { service in
                                streamingChip(service)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if !filters.selectedStreamingServices.isEmpty {
                        Text(selectedStreamingDescription)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: - Runtime

                Section(header: Text("Runtime")) {
                    // Presets (free)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(RuntimePreset.allCases) { preset in
                                Button {
                                    filters.runtimePreset = preset
                                    filters.applyRuntimePresetIfNeeded()
                                } label: {
                                    Text(preset.label)
                                        .font(.footnote)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(
                                            filters.runtimePreset == preset
                                                ? Color.accentColor.opacity(0.18)
                                                : Color(.systemGray6)
                                        )
                                        .foregroundColor(
                                            filters.runtimePreset == preset
                                                ? .accentColor
                                                : .primary
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Custom runtime fields → FilmFuel+
                    if filters.runtimePreset == .custom {
                        if isPremiumUnlocked {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Custom range (FilmFuel+)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Min (min)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        TextField("e.g. 90", text: Binding(
                                            get: { filters.customMinRuntime.map(String.init) ?? "" },
                                            set: { filters.customMinRuntime = Int($0) }
                                        ))
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.roundedBorder)
                                    }

                                    VStack(alignment: .leading) {
                                        Text("Max (min)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        TextField("e.g. 150", text: Binding(
                                            get: { filters.customMaxRuntime.map(String.init) ?? "" },
                                            set: { filters.customMaxRuntime = Int($0) }
                                        ))
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.roundedBorder)
                                    }
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.accentColor)
                                    Text("Custom runtime is a FilmFuel+ feature.")
                                        .font(.footnote)
                                }

                                Button {
                                    onUpgradeTapped?()
                                } label: {
                                    Text("Unlock FilmFuel+")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.accentColor)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                        }
                    }
                }

                // MARK: - Cast & Crew (Premium)

                Section {
                    if isPremiumUnlocked {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "star.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("Cast & Crew Filters (FilmFuel+)")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(.secondary)
                            }

                            TextField("Actor (e.g. Tom Hanks)", text: $filters.actorName)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)

                            TextField("Director (e.g. Christopher Nolan)", text: $filters.directorName)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.accentColor)
                                Text("Filter by actor & director with FilmFuel+.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }

                            Button {
                                onUpgradeTapped?()
                            } label: {
                                Text("Unlock FilmFuel+ Filters")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                } header: {
                    Text("Cast & Crew")
                }

                // MARK: - Favorites only

                Section {
                    Toggle(isOn: $filters.onlyFavorites) {
                        Label("Only Favorites", systemImage: "heart.fill")
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    if filters.isActive {
                        Button(role: .destructive) {
                            filters.reset()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Clear Filters")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func genreChip(_ option: GenreOption) -> some View {
        let isSelected = filters.selectedGenreIDs.contains(option.id)

        return Button {
            if isSelected {
                filters.selectedGenreIDs.remove(option.id)
            } else {
                filters.selectedGenreIDs.insert(option.id)
            }
        } label: {
            Text(option.name)
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 999)
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 999)
                        .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func streamingChip(_ service: StreamingService) -> some View {
        let isSelected = filters.selectedStreamingServices.contains(service)

        return Button {
            if isSelected {
                filters.selectedStreamingServices.remove(service)
            } else {
                filters.selectedStreamingServices.insert(service)
            }
        } label: {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                }
                Text(service.label)
                    .font(.subheadline)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 999)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 999)
                    .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedGenresDescription: String {
        let names = genreOptions
            .filter { filters.selectedGenreIDs.contains($0.id) }
            .map(\.name)
            .sorted()
        return "Selected: " + names.joined(separator: ", ")
    }

    private var selectedStreamingDescription: String {
        let names = StreamingService.allCases
            .filter { filters.selectedStreamingServices.contains($0) }
            .map(\.label)
            .sorted()
        return "Selected: " + names.joined(separator: ", ")
    }
}

#Preview {
    DiscoverFiltersSheet(
        filters: .constant(.default),
        isPremiumUnlocked: false,
        onUpgradeTapped: {}
    )
}
