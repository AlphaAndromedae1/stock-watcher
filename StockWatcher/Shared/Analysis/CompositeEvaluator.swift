import Foundation

/// A custom, transparent "Stock Watcher Score" that blends the signals this app
/// already computes into one 0–100 reading. It is a weighted blend of:
///   • Technicals      (trend/momentum rating)        — 40%
///   • Fundamentals    (valuation/profitability/debt)  — 40%
///   • Analyst view    (consensus recommendation)      — 15%
///   • Analyst target  (implied upside to mean target) —  5%
///
/// Weights are renormalized over whatever data is actually available, so a name
/// with no fundamentals is scored on technicals (+ analyst view) alone. This is
/// an algorithmic blend to focus research, NOT advice or a price prediction.
public enum CompositeEvaluator {

    public enum Band: Int, Sendable, CaseIterable {
        case veryBearish, bearish, mixed, bullish, veryBullish

        public var label: String {
            switch self {
            case .veryBullish: return "Very Bullish"
            case .bullish:     return "Bullish"
            case .mixed:       return "Mixed"
            case .bearish:     return "Bearish"
            case .veryBearish: return "Very Bearish"
            }
        }
    }

    public struct Component: Identifiable, Equatable, Sendable {
        public let label: String
        public let score: Double     // 0…100
        public let weight: Double    // relative
        public let detail: String
        public var id: String { label }
    }

    public struct Result: Equatable, Sendable {
        public let score: Int        // 0…100
        public let band: Band
        public let components: [Component]
    }

    public static func evaluate(technical: TechnicalRating?,
                                fundamentals: Fundamentals,
                                quote: Quote?) -> Result? {
        var comps: [Component] = []

        if let t = technical {
            let s = clamp((t.summaryAverage + 1) / 2 * 100)
            comps.append(Component(label: "Technicals", score: s, weight: 0.40,
                                   detail: t.summary.label))
        }

        if let h = FundamentalAnalyzer.healthScore(fundamentals) {
            comps.append(Component(label: "Fundamentals", score: Double(h), weight: 0.40,
                                   detail: "Health \(h)/100"))
        }

        if let key = fundamentals.recommendationKey, let s = analystScore(key) {
            let pretty = key.replacingOccurrences(of: "_", with: " ").capitalized
            comps.append(Component(label: "Analyst consensus", score: s, weight: 0.15,
                                   detail: pretty))
        }

        if let target = fundamentals.targetMeanPrice, let price = quote?.price, price > 0 {
            let upside = (target - price) / price
            // Map -20% -> 0, +30% -> 100.
            let s = clamp((upside + 0.20) / 0.50 * 100)
            comps.append(Component(label: "Analyst target", score: s, weight: 0.05,
                                   detail: String(format: "%+.0f%% to mean target", upside * 100)))
        }

        guard !comps.isEmpty else { return nil }
        let totalWeight = comps.reduce(0) { $0 + $1.weight }
        let weighted = comps.reduce(0.0) { $0 + $1.score * $1.weight }
        let score = totalWeight > 0 ? weighted / totalWeight : 50
        return Result(score: Int(score.rounded()), band: band(for: score), components: comps)
    }

    private static func analystScore(_ key: String) -> Double? {
        switch key.lowercased() {
        case "strong_buy", "strongbuy": return 100
        case "buy", "outperform", "moderate_buy": return 80
        case "hold", "neutral": return 50
        case "underperform", "moderate_sell": return 30
        case "sell", "strong_sell", "strongsell": return 0
        default: return nil
        }
    }

    public static func band(for score: Double) -> Band {
        switch score {
        case 80...: return .veryBullish
        case 60..<80: return .bullish
        case 40..<60: return .mixed
        case 20..<40: return .bearish
        default: return .veryBearish
        }
    }

    private static func clamp(_ v: Double) -> Double { min(max(v, 0), 100) }
}
