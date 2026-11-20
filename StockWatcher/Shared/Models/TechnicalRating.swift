import Foundation

/// A single indicator's vote.
public enum Signal: Int, Codable, Sendable {
    case buy = 1
    case neutral = 0
    case sell = -1

    public var label: String {
        switch self {
        case .buy: return "Buy"
        case .neutral: return "Neutral"
        case .sell: return "Sell"
        }
    }
}

/// The aggregate recommendation bucket — mirrors TradingView's five levels.
public enum Recommendation: Int, Codable, Sendable, CaseIterable {
    case strongSell = -2
    case sell = -1
    case neutral = 0
    case buy = 1
    case strongBuy = 2

    public var label: String {
        switch self {
        case .strongSell: return "Strong Sell"
        case .sell: return "Sell"
        case .neutral: return "Neutral"
        case .buy: return "Buy"
        case .strongBuy: return "Strong Buy"
        }
    }

    /// Maps an average vote in [-1, 1] to a bucket using TradingView's thresholds.
    public static func from(average: Double) -> Recommendation {
        switch average {
        case let x where x >= 0.5: return .strongBuy
        case let x where x >= 0.1: return .buy
        case let x where x > -0.1: return .neutral
        case let x where x > -0.5: return .sell
        default: return .strongSell
        }
    }
}

/// One line in the indicator breakdown table.
public struct IndicatorResult: Identifiable, Equatable, Codable, Sendable {
    public let name: String
    public let value: Double?
    public let signal: Signal
    public var id: String { name }

    public init(name: String, value: Double?, signal: Signal) {
        self.name = name
        self.value = value
        self.signal = signal
    }
}

/// A group of indicators (Oscillators or Moving Averages) with its tally.
public struct RatingGroup: Equatable, Codable, Sendable {
    public let title: String
    public let results: [IndicatorResult]

    public init(title: String, results: [IndicatorResult]) {
        self.title = title
        self.results = results
    }

    public var buyCount: Int { results.filter { $0.signal == .buy }.count }
    public var sellCount: Int { results.filter { $0.signal == .sell }.count }
    public var neutralCount: Int { results.filter { $0.signal == .neutral }.count }

    /// Average vote across the group's indicators (neutrals pull toward 0).
    public var average: Double {
        guard !results.isEmpty else { return 0 }
        let total = results.reduce(0) { $0 + $1.signal.rawValue }
        return Double(total) / Double(results.count)
    }

    public var recommendation: Recommendation { .from(average: average) }
}

/// Money-flow read: are buyers (accumulation) or sellers (distribution) in control?
public enum Flow: Int, Codable, Sendable {
    case distributing = -1
    case neutral = 0
    case accumulating = 1

    public var label: String {
        switch self {
        case .accumulating: return "Accumulating"
        case .neutral:      return "Neutral flow"
        case .distributing: return "Distributing"
        }
    }
}

/// The full technical evaluation for one symbol at one point in time.
public struct TechnicalRating: Equatable, Codable, Sendable {
    public let oscillators: RatingGroup
    public let movingAverages: RatingGroup
    public let flow: Flow

    public init(oscillators: RatingGroup, movingAverages: RatingGroup, flow: Flow = .neutral) {
        self.oscillators = oscillators
        self.movingAverages = movingAverages
        self.flow = flow
    }

    /// The headline summary, computed over every indicator in both groups
    /// (this is how TradingView's "Summary" gauge is derived).
    public var summaryAverage: Double {
        let all = oscillators.results + movingAverages.results
        guard !all.isEmpty else { return 0 }
        let total = all.reduce(0) { $0 + $1.signal.rawValue }
        return Double(total) / Double(all.count)
    }

    public var summary: Recommendation { .from(average: summaryAverage) }

    public var allResults: [IndicatorResult] { oscillators.results + movingAverages.results }
}
