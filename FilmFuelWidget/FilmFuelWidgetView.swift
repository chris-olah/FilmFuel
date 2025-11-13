import WidgetKit
import SwiftUI

extension Font {
    static var filmfuelQuote: Font {
        .system(.title3, design: .serif).weight(.semibold)
    }
}

extension Font {
    static var filmfuelMiniQuote: Font {
        .system(.footnote, design: .serif).weight(.semibold)
    }
}

struct FilmFuelWidgetView: View {
    let entry: SimpleEntry   // from your Provider

    var body: some View {
        switch contextFamily {
        case .systemSmall:
            SmallView(q: entry.quote)
        case .systemMedium:
            MediumView(q: entry.quote)
        case .accessoryInline:
            InlineAccessoryView(q: entry.quote)
        case .accessoryRectangular:
            RectAccessoryView(q: entry.quote)
        case .accessoryCircular:
            CircularAccessoryView(q: entry.quote)
        default:
            SmallView(q: entry.quote)
        }
    }

    @Environment(\.widgetFamily) private var contextFamily
}

private struct SmallView: View {
    let q: Quote

    var body: some View {
        VStack(spacing: 8) {

            Text("“\(q.text)”")
                .font(.system(.headline, design: .serif))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 6)

            HStack(spacing: 3) {
                Text(q.movie)
                    .font(.caption2)               // san serif small
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.2))
        )
    }
}

private struct MediumView: View {
    let q: Quote

    var body: some View {
        HStack(spacing: 0) {

            VStack(alignment: .leading, spacing: 8) {

                Text("“\(q.text)”")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    Text(q.movie)
                    Text("(\(String(q.year)))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                }
                .font(.footnote)                // san serif small
                .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.2))
        )
    }
}


private struct RectAccessoryView: View {
    let q: Quote
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("“\(q.text)”")
                .font(.filmfuelMiniQuote)
                .lineLimit(3)                 // give it 2–3 lines to breathe
                .minimumScaleFactor(0.55)     // shrink if needed
                .allowsTightening(true)       // squeeze tracking a bit
                .fixedSize(horizontal: false, vertical: true)

            Text(q.movie)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
        }
        .padding(8) // a hair tighter to buy space for text
    }
}

private struct CircularAccessoryView: View {
    let q: Quote
    var body: some View {
        ZStack {
            Text("🎬")
            // Circular faces are tiny; keep it minimal.
        }
        .widgetAccentable()
    }
}

private struct InlineAccessoryView: View {
    let q: Quote

    var body: some View {
        HStack(spacing: 0) {
            Text(shortenFranchise(q.movie))
                .widgetAccentable()
            Text(" — ")
            Text("“\(trimQuote(q.text, relativeTo: q.movie))”")
        }
        .lineLimit(1)
        .allowsTightening(true)     // squeeze before ellipsizing
        .minimumScaleFactor(0.60)   // allow a bit of shrink on long combos
        .truncationMode(.tail)
        //.font(.filmfuelMiniQuote) // optional: leave commented if you prefer system’s default for lock screen
    }

    private func shortenFranchise(_ title: String) -> String {
        title
            .replacingOccurrences(of: "The Lord of the Rings: ", with: "LOTR: ")
            .replacingOccurrences(of: "Star Wars: ", with: "SW: ")
            .replacingOccurrences(of: "Spider-Man: ", with: "SM: ")
            .replacingOccurrences(of: "Harry Potter and the ", with: "HP: ")
    }

    private func trimQuote(_ quote: String, relativeTo movie: String) -> String {
        let base = 36
        let allowance = max(10, base - shortenFranchise(movie).count)
        guard quote.count > allowance else { return quote }
        let idx = quote.index(quote.startIndex, offsetBy: min(allowance, quote.count))
        var slice = String(quote[..<idx])
        if let lastSpace = slice.lastIndex(of: " ") { slice = String(slice[..<lastSpace]) }
        return slice + "…"
    }
}
