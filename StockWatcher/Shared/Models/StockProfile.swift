import Foundation

/// Company / fund profile — the "what is this" info (TradingView-style).
/// Best-effort from Yahoo; every field optional.
public struct StockProfile: Equatable, Sendable, Codable {
    public struct Weight: Equatable, Sendable, Codable, Identifiable {
        public let name: String
        public let pct: Double          // fraction, e.g. 0.28
        public var id: String { name }
        public init(name: String, pct: Double) { self.name = name; self.pct = pct }
    }

    public var quoteType: String?       // EQUITY, ETF, MUTUALFUND
    // Equity
    public var sector: String?
    public var industry: String?
    public var country: String?
    public var website: String?
    public var summary: String?
    public var employees: Int?
    // Fund / ETF
    public var category: String?
    public var family: String?
    public var stockPct: Double?        // asset allocation (fractions)
    public var bondPct: Double?
    public var cashPct: Double?
    public var otherPct: Double?
    public var sectorWeights: [Weight]
    public var topHoldings: [Weight]

    public init() {
        sectorWeights = []
        topHoldings = []
    }

    public var isFund: Bool {
        let t = (quoteType ?? "").uppercased()
        return t == "ETF" || t == "MUTUALFUND"
    }

    public var isEmpty: Bool {
        sector == nil && industry == nil && (summary ?? "").isEmpty && category == nil
            && stockPct == nil && bondPct == nil && sectorWeights.isEmpty && topHoldings.isEmpty
    }
}
