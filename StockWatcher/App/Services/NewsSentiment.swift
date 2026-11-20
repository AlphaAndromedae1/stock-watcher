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

        let average = scores.reduce(0, +) / Double(scores.count)
        let positive = scores.filter { $0 > 0.1 }.count
        let negative = scores.filter { $0 < -0.1 }.count
        let neutral = scores.count - positive - negative
        let label: NewsTone.Label = average > 0.1 ? .positive
                                  : (average < -0.1 ? .negative : .mixed)
        return NewsTone(label: label, average: average,
                        positive: positive, negative: negative, neutral: neutral)
    }
}
