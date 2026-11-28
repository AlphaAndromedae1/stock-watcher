import Foundation

/// One company's inputs for the Magic Formula: the latest annual statements and a price.
/// Any field may be nil when Yahoo doesn't report it.
public struct MagicInputs: Equatable, Sendable {
    public let symbol: String
    public let name: String
    /// False when the annual statements couldn't be fetched at all.
    public let statementsAvailable: Bool
    public let price: Double?
    public let dilutedShares: Double?
    /// Pre-tax income plus interest expense for the latest year.
    public let ebit: Double?
    public let totalDebt: Double?
    public let cash: Double?
    public let currentAssets: Double?
    public let currentLiabilities: Double?
    public let currentDebt: Double?
    public let netPPE: Double?

    public init(symbol: String, name: String, statementsAvailable: Bool, price: Double?,
                dilutedShares: Double?, ebit: Double?, totalDebt: Double?, cash: Double?,
                currentAssets: Double?, currentLiabilities: Double?, currentDebt: Double?,
                netPPE: Double?) {
        self.symbol = symbol
        self.name = name
        self.statementsAvailable = statementsAvailable
        self.price = price
        self.dilutedShares = dilutedShares
        self.ebit = ebit
        self.totalDebt = totalDebt
        self.cash = cash
        self.currentAssets = currentAssets
        self.currentLiabilities = currentLiabilities
        self.currentDebt = currentDebt
        self.netPPE = netPPE
    }
}

/// A ranked company. `rank` is the combined position (1 is best).
public struct MagicRow: Codable, Equatable, Sendable, Identifiable {
    public let symbol: String
    public let name: String
    public let marketCap: Double
    /// EBIT ÷ enterprise value.
    public let earningsYield: Double
    /// EBIT ÷ (net working capital + net PP&E).
    public let returnOnCapital: Double
    public let yieldRank: Int
    public let capitalRank: Int
    public let rank: Int
    public var id: String { symbol }

    public init(symbol: String, name: String, marketCap: Double, earningsYield: Double,
                returnOnCapital: Double, yieldRank: Int, capitalRank: Int, rank: Int) {
        self.symbol = symbol
        self.name = name
        self.marketCap = marketCap
        self.earningsYield = earningsYield
        self.returnOnCapital = returnOnCapital
        self.yieldRank = yieldRank
        self.capitalRank = capitalRank
        self.rank = rank
    }
}

/// A company left out of the ranking, and why.
public struct MagicExclusion: Codable, Equatable, Sendable, Identifiable {
    public let symbol: String
    public let reason: String
    public var id: String { symbol }

    public init(symbol: String, reason: String) {
        self.symbol = symbol
        self.reason = reason
    }
}

public struct MagicRanking: Codable, Equatable, Sendable {
    public let savedAt: Date
    /// How many companies were considered (ranked plus excluded).
    public let universeSize: Int
    public let rows: [MagicRow]
    public let excluded: [MagicExclusion]

    public init(savedAt: Date, universeSize: Int, rows: [MagicRow], excluded: [MagicExclusion]) {
        self.savedAt = savedAt
        self.universeSize = universeSize
        self.rows = rows
        self.excluded = excluded
    }
}

/// Greenblatt's Magic Formula: rank by earnings yield and by return on capital, then
/// add the two ranks. Informational only, and never part of the Stock Watcher Score.
public enum MagicFormula {
    /// Every TSX catalog name except financials (banks and insurers). Greenblatt also
    /// excluded utilities; they stay in because the agreed universe is 59 names.
    public static var universe: [TSXCatalog.Entry] {
        TSXCatalog.all.filter { $0.sector != "Financials" }
    }

    public static func rank(_ inputs: [MagicInputs], savedAt: Date = Date()) -> MagicRanking {
        var scored: [Scored] = []
        var excluded: [MagicExclusion] = []

        for item in inputs {
            if !item.statementsAvailable {
                excluded.append(MagicExclusion(symbol: item.symbol, reason: "Annual statements unavailable"))
                continue
            }
            guard let price = item.price, price > 0 else {
                excluded.append(MagicExclusion(symbol: item.symbol, reason: "No current price"))
                continue
            }
            guard let shares = item.dilutedShares, shares > 0 else {
                excluded.append(MagicExclusion(symbol: item.symbol, reason: "Share count missing"))
                continue
            }
            guard let ebit = item.ebit else {
                excluded.append(MagicExclusion(symbol: item.symbol,
                                               reason: "EBIT unavailable (no interest expense reported)"))
                continue
            }
            guard ebit > 0 else {
                excluded.append(MagicExclusion(symbol: item.symbol, reason: "EBIT not positive"))
                continue
            }
            guard let ca = item.currentAssets, let cl = item.currentLiabilities, let ppe = item.netPPE else {
                excluded.append(MagicExclusion(symbol: item.symbol, reason: "Balance sheet incomplete"))
                continue
            }

            // Market cap is price × diluted shares. Enterprise value adds total debt
            // (which includes leases) and subtracts cash and short-term investments.
            let marketCap = price * shares
            let debt = item.totalDebt ?? 0
            let cash = item.cash ?? 0
            let enterpriseValue = marketCap + debt - cash
            guard enterpriseValue > 0 else {
                excluded.append(MagicExclusion(symbol: item.symbol, reason: "Enterprise value not positive"))
                continue
            }

            // Net working capital excludes cash and current debt.
            let currentDebt = item.currentDebt ?? 0
            let workingCapital = (ca - cash) - (cl - currentDebt)
            let capital = workingCapital + ppe
            guard capital > 0 else {
                excluded.append(MagicExclusion(symbol: item.symbol, reason: "Invested capital not positive"))
                continue
            }

            scored.append(Scored(input: item, marketCap: marketCap,
                                 earningsYield: ebit / enterpriseValue,
                                 returnOnCapital: ebit / capital))
        }

        // Rank each measure (1 is best), then order by the sum, breaking ties on yield.
        let yieldOrder = scored.indices.sorted { scored[$0].earningsYield > scored[$1].earningsYield }
        let capitalOrder = scored.indices.sorted { scored[$0].returnOnCapital > scored[$1].returnOnCapital }
        var yieldRank = Array(repeating: 0, count: scored.count)
        var capitalRank = Array(repeating: 0, count: scored.count)
        for (position, index) in yieldOrder.enumerated() {
            yieldRank[index] = position + 1
        }
        for (position, index) in capitalOrder.enumerated() {
            capitalRank[index] = position + 1
        }

        let finalOrder = scored.indices.sorted { a, b in
            let sumA = yieldRank[a] + capitalRank[a]
            let sumB = yieldRank[b] + capitalRank[b]
            if sumA != sumB {
                return sumA < sumB
            }
            return scored[a].earningsYield > scored[b].earningsYield
        }

        var rows: [MagicRow] = []
        for (position, index) in finalOrder.enumerated() {
            let s = scored[index]
            rows.append(MagicRow(symbol: s.input.symbol, name: s.input.name, marketCap: s.marketCap,
                                 earningsYield: s.earningsYield, returnOnCapital: s.returnOnCapital,
                                 yieldRank: yieldRank[index], capitalRank: capitalRank[index],
                                 rank: position + 1))
        }
        return MagicRanking(savedAt: savedAt, universeSize: inputs.count, rows: rows, excluded: excluded)
    }

    private struct Scored {
        let input: MagicInputs
        let marketCap: Double
        let earningsYield: Double
        let returnOnCapital: Double
    }
}
