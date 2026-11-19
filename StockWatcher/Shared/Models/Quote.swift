import Foundation

/// A lightweight live snapshot of a symbol — what the widget and list rows need.
public struct Quote: Equatable, Codable, Sendable {
    public let symbol: String
    public let shortName: String?
    public let currency: String?
    public let price: Double
    public let previousClose: Double
    public let exchange: String?
    public let asOf: Date

    public init(symbol: String, shortName: String?, currency: String?,
                price: Double, previousClose: Double, exchange: String?, asOf: Date) {
        self.symbol = symbol
        self.shortName = shortName
        self.currency = currency
        self.price = price
        self.previousClose = previousClose
        self.exchange = exchange
        self.asOf = asOf
    }

    public var change: Double { price - previousClose }
    public var changePercent: Double {
        guard previousClose != 0 else { return 0 }
        return (price - previousClose) / previousClose * 100
    }
    public var isUp: Bool { change >= 0 }
}

/// Best-effort fundamentals. Every field is optional: Yahoo's fundamentals
/// endpoint is rate-limited / crumb-gated, so the UI must degrade gracefully.
public struct Fundamentals: Equatable, Codable, Sendable {
    public var marketCap: Double?
    public var trailingPE: Double?
    public var forwardPE: Double?
    public var priceToBook: Double?
    public var pegRatio: Double?
    public var dividendYield: Double?       // as a fraction, e.g. 0.042 == 4.2%
    public var profitMargin: Double?        // fraction
    public var returnOnEquity: Double?      // fraction
    public var debtToEquity: Double?        // ratio (e.g. 55.0 == 55%)
    public var revenueGrowth: Double?       // fraction YoY
    public var earningsGrowth: Double?      // fraction YoY
    public var beta: Double?
    public var fiftyTwoWeekHigh: Double?
    public var fiftyTwoWeekLow: Double?
    public var recommendationKey: String?   // yahoo analyst consensus, e.g. "buy"
    public var numberOfAnalysts: Int?
    public var targetMeanPrice: Double?
    public var dividendRate: Double?        // annual $ per share
    public var exDividendDate: Date?
    public var nextEarningsDate: Date?
    public var shortPercentOfFloat: Double? // fraction of float sold short
    public var shortRatio: Double?          // days-to-cover
    public var insiderNetShares: Double?    // net insider shares bought(+)/sold(-), ~6mo

    public init() {}

    public var isEmpty: Bool {
        marketCap == nil && trailingPE == nil && forwardPE == nil && priceToBook == nil
            && pegRatio == nil && dividendYield == nil && profitMargin == nil
            && returnOnEquity == nil && debtToEquity == nil && revenueGrowth == nil
            && earningsGrowth == nil && beta == nil && recommendationKey == nil
            && targetMeanPrice == nil && shortPercentOfFloat == nil && insiderNetShares == nil
    }
}
