import Foundation

/// Runs the Magic Formula on the phone. Each name's annual statements come from the
/// same daily cache the Piotroski and Altman scores use, and each name needs one price.
/// Names are processed four at a time with a short pause between batches, so Yahoo
/// isn't hit in bursts. The finished ranking is cached for a day.
public enum MagicFormulaRunner {
    public static let cacheKey = "magic.ranking.v2"
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
        // One exchange rate for the whole run (CAD per USD), used to convert U.S.-dollar statements.
        let usdToCad = (try? await YahooService.shared.fetchQuote(symbol: "CAD=X"))?.price
        var inputs: [MagicInputs] = []
        var start = 0

        while start < universe.count {
            let end = min(start + batchSize, universe.count)
            let batch = Array(universe[start..<end])
            let results = await withTaskGroup(of: MagicInputs.self) { group -> [MagicInputs] in
                for entry in batch {
                    group.addTask { await loadInputs(entry, usdToCad: usdToCad) }
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

    private static func loadInputs(_ entry: TSXCatalog.Entry, usdToCad: Double?) async -> MagicInputs {
        let symbol = entry.symbol
        let series = await YahooService.shared.fetchAnnualSeries(symbol: symbol)
        let quote = try? await YahooService.shared.fetchQuote(symbol: symbol)
        let price = quote?.price
        let quoteCurrency = quote?.currency

        guard let series, !series.isEmpty else {
            return MagicInputs(symbol: symbol, name: entry.name, statementsAvailable: false,
                               price: price, dilutedShares: nil, ebit: nil, totalDebt: nil,
                               cash: nil, currentAssets: nil, currentLiabilities: nil,
                               currentDebt: nil, netPPE: nil, quoteCurrency: quoteCurrency)
        }

        let latest = AnnualYears.build(series, maxYears: 1).first?.values ?? [:]
        let statementCurrency = series.values.compactMap { $0.first?.currency }.first

        // Monetary inputs are converted into the price currency. Shares are counts, so they aren't.
        let conversion = currencyConversion(from: statementCurrency, to: quoteCurrency, usdToCad: usdToCad)
        let factor = conversion.factor
        func scaled(_ key: String) -> Double? {
            guard let value = latest[key] else { return nil }
            return value * factor
        }

        var ebit: Double? = nil
        if let pretax = scaled("annualPretaxIncome"), let interest = scaled("annualInterestExpense") {
            ebit = pretax + interest
        }

        return MagicInputs(
            symbol: symbol,
            name: entry.name,
            statementsAvailable: true,
            price: price,
            dilutedShares: latest["annualDilutedAverageShares"],
            ebit: ebit,
            totalDebt: scaled("annualTotalDebt"),
            cash: scaled("annualCashCashEquivalentsAndShortTermInvestments"),
            currentAssets: scaled("annualCurrentAssets"),
            currentLiabilities: scaled("annualCurrentLiabilities"),
            currentDebt: scaled("annualCurrentDebtAndCapitalLeaseObligation"),
            netPPE: scaled("annualNetPPE"),
            // If conversion wasn't possible, the currencies stay different and the ranker excludes the name.
            statementCurrency: conversion.converted ? quoteCurrency : statementCurrency,
            quoteCurrency: quoteCurrency,
            otherIncome: scaled("annualOtherIncomeExpense")
        )
    }

    /// Factor that turns statement amounts into the price currency, and whether that
    /// conversion was possible. Only the USD/CAD pair is converted; anything else is left as is.
    private static func currencyConversion(from statement: String?, to quote: String?,
                                           usdToCad: Double?) -> (factor: Double, converted: Bool) {
        guard let statement, let quote, statement != quote else {
            return (1, false)
        }
        if statement == "USD", quote == "CAD", let rate = usdToCad, rate > 0 {
            return (rate, true)
        }
        if statement == "CAD", quote == "USD", let rate = usdToCad, rate > 0 {
            return (1 / rate, true)
        }
        return (1, false)
    }
}
