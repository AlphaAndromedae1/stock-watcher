import Foundation

// Tier-1 quantitative checks, built only from data the app already loads
// (price history, volume and valuation ratios). Informational: shown on the
// detail screen and never fed into the Stock Watcher Score.

public struct GrahamValuation: Equatable, Sendable {
    /// Graham Number: √(22.5 × EPS × book value per share). A conservative ceiling.
    public let value: Double
    /// (value − price) ÷ value. Positive means the price sits below the ceiling.
    public let marginOfSafety: Double
}

public struct SectorValuation: Equatable, Sendable {
    public let sectorName: String
    public let ownPE: Double
    public let peerMedianPE: Double
    public let peerCount: Int
    /// ownPE ÷ peerMedianPE − 1. Positive means a premium to peers.
    public let premium: Double
}

public struct WithholdingNote: Equatable, Sendable {
    public let text: String
    /// Yearly drag as a fraction of the holding's price (yield × 15%). 0 when no
    /// loss applies; nil when the rule depends on the country and we don't guess.
    public let drag: Double?
}

public struct QuantSnapshot: Equatable, Sendable {
    public var graham: GrahamValuation? = nil
    public var sector: SectorValuation? = nil
    /// ≈12-1 return as a fraction: roughly 11 months, skipping the latest month.
    public var momentum: Double? = nil
    /// The same measure for the market benchmark (TSX Composite or S&P 500).
    public var benchmarkMomentum: Double? = nil
    /// Annualised volatility from daily log returns, as a fraction.
    public var volatility: Double? = nil
    /// Worst peak-to-trough fall in the window (≤ 0).
    public var maxDrawdown: Double? = nil
    /// Fall from the window's high to the latest close (≤ 0).
    public var currentDrawdown: Double? = nil
    /// One-year return ÷ volatility. No risk-free rate is subtracted.
    public var returnPerRisk: Double? = nil
    /// Average daily value traded (price × volume) over about three months.
    public var avgDollarVolume: Double? = nil
    public var withholding: WithholdingNote? = nil

    public init() {}
}

public enum QuantMetrics {
    /// Trading days in a year, used to annualise volatility.
    static let tradingDays = 252
    /// Share of U.S. dividends withheld at source under the Canada-U.S. treaty.
    static let usWithholdingRate = 0.15

    // MARK: Valuation

    /// Graham Number = √(22.5 × EPS × book value per share). Only defined for
    /// profitable companies with positive book value; nil otherwise.
    public static func graham(price: Double, trailingPE: Double?, priceToBook: Double?) -> GrahamValuation? {
        guard price > 0, let pe = trailingPE, pe > 0, let pb = priceToBook, pb > 0 else { return nil }
        let eps = price / pe
        let bookPerShare = price / pb
        let product = 22.5 * eps * bookPerShare
        guard product > 0 else { return nil }
        let value = product.squareRoot()
        let margin = (value - price) / value
        return GrahamValuation(value: value, marginOfSafety: margin)
    }

    /// Where this stock's P/E sits against the median of same-sector peers.
    /// Needs at least three valid peer P/Es, or nil.
    public static func sectorValuation(ownPE: Double?, peerPEs: [Double], sectorName: String) -> SectorValuation? {
        guard let pe = ownPE, pe > 0 else { return nil }
        let valid = peerPEs.filter { $0.isFinite && $0 > 0 }.sorted()
        guard valid.count >= 3 else { return nil }
        let mid = valid.count / 2
        let median = valid.count % 2 == 0 ? (valid[mid - 1] + valid[mid]) / 2 : valid[mid]
        let premium = pe / median - 1
        return SectorValuation(sectorName: sectorName, ownPE: pe, peerMedianPE: median,
                               peerCount: valid.count, premium: premium)
    }

    /// Same-sector TSX catalog peers, excluding the stock itself, capped at `limit`.
    /// Catalog sectors are coarse (e.g. "Consumer" mixes grocers and auto parts).
    public static func peers(for symbol: String, limit: Int = 6) -> (sector: String, symbols: [String])? {
        guard let entry = TSXCatalog.all.first(where: {
            $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame
        }) else { return nil }
        let others: [String] = TSXCatalog.all
            .filter { $0.sector == entry.sector && $0.symbol.caseInsensitiveCompare(symbol) != .orderedSame }
            .prefix(limit)
            .map { $0.symbol }
        return (entry.sector, others)
    }

    // MARK: Momentum

    /// ≈12-1 momentum: the return from about 12 months ago to about 1 month ago,
    /// skipping the latest month. Yahoo's one-year window is ~252 bars, so the
    /// start is clamped to the earliest bar rather than requiring a full year.
    public static func momentum(_ closes: [Double]) -> Double? {
        let n = closes.count
        guard n >= 40 else { return nil }
        let endIdx = n - 1 - 21
        let startIdx = max(0, n - 1 - tradingDays)
        guard endIdx > startIdx else { return nil }
        let start = closes[startIdx]
        let end = closes[endIdx]
        guard start > 0, end.isFinite else { return nil }
        return end / start - 1
    }

    // MARK: Risk

    /// Annualised volatility from daily log returns.
    public static func volatility(_ closes: [Double]) -> Double? {
        guard closes.count >= 20 else { return nil }
        var logReturns: [Double] = []
        logReturns.reserveCapacity(closes.count - 1)
        for i in 1..<closes.count {
            let prev = closes[i - 1]
            let cur = closes[i]
            guard prev > 0, cur > 0 else { return nil }
            logReturns.append(log(cur / prev))
        }
        let count = Double(logReturns.count)
        let mean = logReturns.reduce(0, +) / count
        var sumSquares = 0.0
        for r in logReturns {
            let d = r - mean
            sumSquares += d * d
        }
        let variance = sumSquares / (count - 1)
        let annualFactor = Double(tradingDays).squareRoot()
        return variance.squareRoot() * annualFactor
    }

    /// Worst peak-to-trough decline in the window (≤ 0).
    public static func maxDrawdown(_ closes: [Double]) -> Double? {
        guard closes.count >= 2 else { return nil }
        var peak = closes[0]
        var worst = 0.0
        for c in closes {
            peak = max(peak, c)
            guard peak > 0 else { continue }
            let dd = c / peak - 1
            worst = min(worst, dd)
        }
        return worst
    }

    /// How far the latest close sits below the window's high (≤ 0).
    public static func currentDrawdown(_ closes: [Double]) -> Double? {
        guard let last = closes.last, let peak = closes.max(), peak > 0 else { return nil }
        return last / peak - 1
    }

    /// One-year (window) return divided by annualised volatility. Named plainly
    /// because no risk-free rate is subtracted, so it is not the Sharpe ratio.
    public static func returnPerRisk(closes: [Double], volatility: Double?) -> Double? {
        guard let vol = volatility, vol > 0, let first = closes.first, let last = closes.last, first > 0 else {
            return nil
        }
        let totalReturn = last / first - 1
        return totalReturn / vol
    }

    /// Average daily value traded (price × volume) over the last ~3 months.
    public static func averageDollarVolume(_ candles: [Candle], days: Int = 63) -> Double? {
        let window = candles.suffix(days)
        guard window.count >= 10 else { return nil }
        var total = 0.0
        for c in window { total += c.close * c.volume }
        return total / Double(window.count)
    }

    // MARK: Tax notes

    /// Withholding notes limited to what is verified: 15% U.S. withholding on U.S.
    /// dividends and how each account treats it. Canadian dividends get qualitative
    /// notes only, because real after-tax figures depend on province and bracket.
    public static func withholding(symbol: String, dividendYield: Double?,
                                   account: TaxAccount, isFund: Bool = false) -> WithholdingNote? {
        guard let y = dividendYield, y > 0, y.isFinite else { return nil }
        let upper = symbol.uppercased()

        if upper.hasSuffix(".TO") || upper.hasSuffix(".V") {
            var text = canadianNote(account)
            if isFund {
                text += " Canadian-listed funds that hold U.S. stocks can still lose some yield to U.S. withholding inside the fund."
            }
            return WithholdingNote(text: text, drag: 0)
        }

        // A dot in the symbol means a non-U.S., non-Canadian listing: rates vary by country.
        if upper.contains(".") {
            return WithholdingNote(
                text: "Foreign listing: withholding rates depend on the country. Check the rules for that market.",
                drag: nil)
        }

        // Plain ticker: treated as a U.S. listing.
        switch account {
        case .tfsa:
            let drag = y * usWithholdingRate
            return WithholdingNote(
                text: "U.S. dividends have about 15% withheld at source. In a TFSA that generally can't be recovered, so it is a real yearly cost.",
                drag: drag)
        case .rrsp:
            return WithholdingNote(
                text: "Held directly in an RRSP or RRIF, U.S. dividends are generally exempt from the 15% withholding under the Canada-U.S. treaty.",
                drag: 0)
        case .nonRegistered:
            return WithholdingNote(
                text: "U.S. dividends have about 15% withheld at source. In a non-registered account it is generally recoverable through the foreign tax credit.",
                drag: 0)
        }
    }

    private static func canadianNote(_ account: TaxAccount) -> String {
        switch account {
        case .tfsa:
            return "Canadian dividends are tax-free inside a TFSA."
        case .rrsp:
            return "Canadian dividends grow tax-deferred inside an RRSP. Withdrawals are taxed as income."
        case .nonRegistered:
            return "Eligible Canadian dividends get the dividend tax credit, which lowers the effective tax rate."
        }
    }

    // MARK: Snapshot

    /// Builds every Tier-1 check for one stock. Graham and sector P/E apply only
    /// to a confirmed operating company, so a fund never shows them.
    public static func snapshot(symbol: String, candles: [Candle], benchmark: [Candle]?,
                                price: Double?, trailingPE: Double?, priceToBook: Double?,
                                dividendYield: Double?, isOperatingCompany: Bool, isFund: Bool,
                                sectorName: String?, peerPEs: [Double],
                                account: TaxAccount) -> QuantSnapshot {
        var s = QuantSnapshot()
        let closes = candles.map(\.close)

        if isOperatingCompany, let p = price {
            s.graham = graham(price: p, trailingPE: trailingPE, priceToBook: priceToBook)
            if let name = sectorName {
                s.sector = sectorValuation(ownPE: trailingPE, peerPEs: peerPEs, sectorName: name)
            }
        }

        s.momentum = momentum(closes)
        if let b = benchmark {
            s.benchmarkMomentum = momentum(b.map(\.close))
        }
        s.volatility = volatility(closes)
        s.maxDrawdown = maxDrawdown(closes)
        s.currentDrawdown = currentDrawdown(closes)
        s.returnPerRisk = returnPerRisk(closes: closes, volatility: s.volatility)
        s.avgDollarVolume = averageDollarVolume(candles)
        s.withholding = withholding(symbol: symbol, dividendYield: dividendYield,
                                    account: account, isFund: isFund)
        return s
    }
}
