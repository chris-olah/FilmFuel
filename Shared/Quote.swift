//
//  Quote.swift
//  FilmFuel
//

import Foundation

// MARK: - Quote model aligned with your JSON
// {
//   "date": "2025-11-01",
//   "quote": "Hope is a good thing...",
//   "movie": "The Shawshank Redemption",
//   "year": 1994,
//   "triviaQuestion": "...",
//   "choices": [...],
//   "correctIndex": 0,
//   "funFact": "..."
// }

struct Quote: Identifiable, Equatable, Decodable {
    var id: UUID = UUID()

    let date: String
    let text: String
    let movie: String
    let year: Int
    let trivia: Trivia
    let funFact: String?

    enum CodingKeys: String, CodingKey {
        case date
        case text = "quote"
        case movie
        case year
        case triviaQuestion
        case choices
        case correctIndex
        case funFact
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        date  = try c.decode(String.self, forKey: .date)
        text  = try c.decode(String.self, forKey: .text)
        movie = try c.decode(String.self, forKey: .movie)

        // Year may be Int or String ("1994,")
        if let intYear = try? c.decode(Int.self, forKey: .year) {
            year = intYear
        } else if let str = try? c.decode(String.self, forKey: .year) {
            year = Int(str.filter { $0.isNumber }) ?? 0
        } else {
            year = 0
        }

        let question = (try? c.decode(String.self, forKey: .triviaQuestion)) ?? ""
        let choices = (try? c.decode([String].self, forKey: .choices)) ?? []
        let index = (try? c.decode(Int.self, forKey: .correctIndex)) ?? 0
        trivia = Trivia(question: question, choices: choices, correctIndex: index)

        funFact = try? c.decode(String.self, forKey: .funFact)
    }

    // Manual initializer
    init(date: String, text: String, movie: String, year: Int,
         trivia: Trivia, funFact: String? = nil) {
        self.id = UUID()
        self.date = date
        self.text = text
        self.movie = movie
        self.year = year
        self.trivia = trivia
        self.funFact = funFact
    }
}

// MARK: - Trivia model
struct Trivia: Equatable, Decodable {
    let question: String
    let choices: [String]
    let correctIndex: Int

    enum CodingKeys: String, CodingKey {
        case question
        case choices
        case correctIndex
    }

    init(question: String, choices: [String], correctIndex: Int) {
        self.question = question
        self.choices = choices.isEmpty ? [""] : choices
        self.correctIndex = min(max(0, correctIndex), max(choices.count - 1, 0))
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        let q = (try? c.decode(String.self, forKey: .question)) ?? ""
        let ch = (try? c.decode([String].self, forKey: .choices)) ?? []
        let idx = (try? c.decode(Int.self, forKey: .correctIndex)) ?? 0

        self.init(question: q, choices: ch, correctIndex: idx)
    }

    var correctAnswer: String? {
        guard correctIndex >= 0, correctIndex < choices.count else { return nil }
        return choices[correctIndex]
    }
}
