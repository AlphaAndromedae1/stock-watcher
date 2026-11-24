import Foundation
import NaturalLanguage

/// An informational read on recent-headline tone. Uses Apple's on-device
/// Natural Language sentiment (no network, no key, private). Deliberately NOT
/// fed into the Stock Watcher Score — headline sentiment is noisy as a signal.
struct NewsTone: Equatable {
    enum Label: Equatable {
        case positive, mixed, negative

        var title: String {
            switch self {
            case .positive: return "Positive"
            case .mixed:    return "Mixed"
            case .negative: return "Negative"
            }
        }
    }

    let label: Label
    let average: Double      // -1 … 1
    let positive: Int
    let negative: Int
    let neutral: Int

    var total: Int { positive + negative + neutral }
}

enum NewsSentiment {
    /// Scores each headline's sentiment and summarizes the overall tone.
    static func analyze(_ items: [NewsItem]) -> NewsTone? {
        guard !items.isEmpty else { return nil }
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        var scores: [Double] = []
        for item in items {
            let text = item.title
            guard !text.isEmpty else { continue }
            tagger.string = text
            let (tag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
            if let raw = tag?.rawValue, let value = Double(raw) {
                scores.append(value)
            }
        }
        guard !scores.isEmpty else { return nil }

        // Apple's on-device model skews negative on terse financial headlines
        // ("shares slip", "misses estimates"), so a neutral news day reads as
        // "Negative" with a tight band. We nudge the midpoint up slightly and
        // widen the neutral band so only clearly polarized headlines move the
        // tone off "Mixed". This read is informational only (never scored).
        let debias = 0.15
        let adjusted = scores.map { $0 + debias }
        let average = adjusted.reduce(0, +) / Double(adjusted.count)
        let positive = adjusted.filter { $0 > 0.3 }.count
        let negative = adjusted.filter { $0 < -0.3 }.count
        let neutral = adjusted.count - positive - negative
        let label: NewsTone.Label = average > 0.2 ? .positive
                                  : (average < -0.2 ? .negative : .mixed)
        return NewsTone(label: label, average: average,
                        positive: positive, negative: negative, neutral: neutral)
    }
}
