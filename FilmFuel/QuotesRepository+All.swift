import Foundation

extension QuotesRepository {
    /// Loads the entire quotes.json into an array of Quote
    func allQuotes() -> [Quote]? {
        // The base name of your file — no .json extension here
        let fileName = "quotes"

        // Look for quotes.json inside your app (or widget) bundle
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("❌ Could not find \(fileName).json in bundle")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let list = try JSONDecoder().decode([Quote].self, from: data)
            return list
        } catch {
            print("❌ Failed to decode \(fileName).json: \(error)")
            return nil
        }
    }

    /// Returns a random selection of quotes (or the entire list if no limit)
    func randomized(limit: Int? = nil) -> [Quote] {
        let all = allQuotes() ?? []
        guard let limit, limit > 0 else { return all.shuffled() }
        return Array(all.shuffled().prefix(limit))
    }

    /// Normalizes movie titles for OMDb lookup (e.g. strips "(Final Cut)")
    func omdbTitle(for raw: String) -> String {
        var t = raw.replacingOccurrences(of: #"\s*\(.*?\)"#,
                                         with: "",
                                         options: .regularExpression)
        if let idx = t.firstIndex(of: ":") {
            t = String(t[..<idx])
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
