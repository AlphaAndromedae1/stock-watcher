import Foundation

/// Runs the Magic Formula on the phone. Each name's annual statements come from the
/// same daily cache the Piotroski and Altman scores use, and each name needs one price.
/// Names are processed four at a time with a short pause between batches, so Yahoo
/// isn't hit in bursts. The finished ranking is cached for a day.
public enum MagicFormulaRunner {
    public static let cacheKey = "magic.ranking.v1"
    /// A ranking older than this is not shown; the user runs it again.
    public static let cacheTTL: TimeInterval = 24 * 60 * 60

    /// The last ranking, if it is still fresh.
    public static func cachedRanking() -> MagicRanking? {
        let cache = DataCache.shared
        guard let age = cache.age(key: cacheKey), age < cacheTTL else { return nil }
        return cache.load(MagicRanking.self, key: cacheKey)
    }

    /// Ranks the universe and caches the result. `progress` reports 0...1 as batches finish.
    public static func run(progress: @Sendable (Double) -> Void) async -> MagicRanking {
        let universe = MagicFormula.universe
        let batchSize = 4
        var inputs: [MagicInputs] = []
        var start = 0

        while start < universe.count {
            let end = min(start + batchSize, universe.count)
            let batch = Array(universe[start..<end])
            let results = await withTaskGroup(of: MagicInputs.self) { group -> [MagicInputs] in
                for entry in batch {
                    group.addTask { await loadInputs(entry) }
                }
                var out: [MagicInputs] = []
                for await item in group {
                    out.append(item)
                }
                return out
            }
            inputs.append(contentsOf: results)
            start = end
            progress(Double(start) / Double(universe.count))
            if start < universe.count {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }

        let ranking = MagicFormula.rank(inputs)
        DataCache.shared.save(ranking, key: cacheKey)
        // Clear out anything else the app has stopped using.
        _ = DataCache.shared.purge(olderThan: 7 * 24 * 60 * 60)
        return ranking
    }

    private static func loadInputs(_ entry: TSXCatalog.Entry) async -> MagicInputs {
        let symbol = entry.symbol
        let series = await YahooService.shared.fetchAnnualSeries(symbol: symbol)
        let quote = try? await YahooService.shared.fetchQuote(symbol: symbol)
        let price = quote?.price

        guard let series, !series.isEmpty else {
            return MagicInputs(symbol: symbol, name: entry.name, statementsAvailable: false,
                               price: price, dilutedShares: nil, ebit: nil, totalDebt: nil,
                               cash: nil, currentAssets: nil, currentLiabilities: nil,
                               currentDebt: nil, netPPE: nil)
        }

        let latest = AnnualYears.build(series, maxYears: 1).first?.values ?? [:]
        var ebit: Double? = nil
        if let pretax = latest["annualPretaxIncome"], let interest = latest["annualInterestExpense"] {
            ebit = pretax + interest
        }

        return MagicInputs(
            symbol: symbol,
            name: entry.name,
            statementsAvailable: true,
            price: price,
            dilutedShares: latest["annualDilutedAverageShares"],
            ebit: ebit,
            totalDebt: latest["annualTotalDebt"],
            cash: latest["annualCashCashEquivalentsAndShortTermInvestments"],
            currentAssets: latest["annualCurrentAssets"],
            currentLiabilities: latest["annualCurrentLiabilities"],
            currentDebt: latest["annualCurrentDebtAndCapitalLeaseObligation"],
            netPPE: latest["annualNetPPE"]
        )
    }
}
