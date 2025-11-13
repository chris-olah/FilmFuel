//
//  QuotesRepository.swift
//  FilmFuel
//
//  Created by Chris Olah on 11/6/25.
//

import Foundation

/// Loads quotes.json once and offers lookups by "YYYY-MM-DD".
final class QuotesRepository {

    // Preferred shared instance so you don't reload JSON everywhere
    static let shared = QuotesRepository()

    // Stored data
    private(set) var quotes: [Quote] = []
    private var byDate: [String: Quote] = [:]

    private var hasLoaded = false
    private let fileName: String

    // MARK: - Init

    /// You can pass a custom file name, but most code should use `shared`.
    init(jsonFileName: String = "quotes") {
        self.fileName = jsonFileName
        loadJSONIfNeeded()
    }

    // MARK: - Public API

    /// Exact match by YYYY-MM-DD
    func quote(forDayKey key: String) -> Quote? {
        byDate[key]
    }

    /// Fallback rotation if an exact date is missing (optional but handy).
    func rotatingQuote(forDayKey key: String) -> Quote? {
        guard !quotes.isEmpty else { return nil }
        let num = Int(key.replacingOccurrences(of: "-", with: "")) ?? 0
        return quotes[abs(num) % quotes.count]
    }

    // MARK: - Loading

    private func loadJSONIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadJSON(named: fileName)
    }

    private func loadJSON(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            print("⚠️ quotes.json not found in bundle for targets that include it.")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            var decoded = try JSONDecoder().decode([Quote].self, from: data)

            // Synthesize UUIDs so SwiftUI ForEach works consistently
            decoded = decoded.map { q in
                var copy = q
                copy.id = UUID()
                return copy
            }

            // Build date index (assumes dates are unique)
            var map: [String: Quote] = [:]
            for q in decoded {
                map[q.date] = q
            }

            self.quotes = decoded
            self.byDate = map
        } catch {
            print("⚠️ Failed to decode quotes.json: \(error)")
        }
    }
}
