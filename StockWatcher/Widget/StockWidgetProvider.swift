import WidgetKit
import SwiftUI

/// One row shown in the widget.
struct WidgetRow: Identifiable, Hashable {
    let symbol: String        // display symbol, e.g. "RY"
    let fullSymbol: String    // Yahoo symbol, e.g. "RY.TO" (for deep links)
    let name: String
    let price: Double
    let changePercent: Double
    let isUp: Bool
    let hasData: Bool
    let score: Int?                       // Stock Watcher Score 0…100
    let band: CompositeEvaluator.Band?
    var id: String { fullSymbol }
}

struct StockEntry: TimelineEntry {
    let date: Date
    let rows: [WidgetRow]
    let isPlaceholder: Bool
    let mood: MarketMood?

    static let sample = StockEntry(
        date: Date(),
        rows: [
            WidgetRow(symbol: "XEQT", fullSymbol: "XEQT.TO", name: "iShares Core Equity ETF", price: 36.84, changePercent: 0.42, isUp: true, hasData: true, score: 68, band: .bullish),
            WidgetRow(symbol: "SU", fullSymbol: "SU.TO", name: "Suncor Energy", price: 58.21, changePercent: -0.63, isUp: false, hasData: true, score: 51, band: .mixed),
            WidgetRow(symbol: "CHPS", fullSymbol: "CHPS.TO", name: "CHPS", price: 24.17, changePercent: 1.12, isUp: true, hasData: true, score: 72, band: .bullish),
            WidgetRow(symbol: "Gold 10K", fullSymbol: "GC=F", name: "Per gram · CAD", price: 49.73, changePercent: 0.55, isUp: true, hasData: true, score: nil, band: nil)
        ],
        isPlaceholder: true,
        mood: MarketMood(vix: 17.4, vixChangePercent: -3.1, vixc: 15.9, asOf: Date()))
}

struct StockProvider: TimelineProvider {
    func placeholder(in context: Context) -> StockEntry {
        StockEntry.sample
    }

    func getSnapshot(in context: Context, completion: @escaping (StockEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
            return
        }
        Task { completion(await Self.loadEntry(limit: maxItems(for: context.family))) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StockEntry>) -> Void) {
        Task {
            let entry = await Self.loadEntry(limit: maxItems(for: context.family))
            // Refresh ~every 30 min during TSX hours; otherwise park the next
            // wake-up at the following session's open so we don't poll overnight.
            let next = MarketHours.nextWidgetRefresh(intervalMinutes: 30)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func maxItems(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 2
        case .systemMedium: return 3
        case .systemLarge: return 6
        case .accessoryRectangular: return 2
        default: return 3
        }
    }

    static func loadMood() async -> MarketMood? {
        let vix = try? await YahooService.shared.fetchQuote(symbol: "^VIX")
        let vixc = try? await YahooService.shared.fetchQuote(symbol: "^VIXC")
        guard vix != nil || vixc != nil else { return nil }
        return MarketMood(vix: vix?.price, vixChangePercent: vix?.changePercent,
                          vixc: vixc?.price, asOf: Date())
    }

    /// 10-karat gold price per gram in CAD, from gold futures × USD/CAD.
    static func loadGoldRow() async -> WidgetRow? {
        let gold = try? await YahooService.shared.fetchQuote(symbol: "GC=F")   // USD per troy oz
        let fx = try? await YahooService.shared.fetchQuote(symbol: "CAD=X")    // CAD per USD
        guard let gold, let fx, gold.price > 0, fx.price > 0 else { return nil }
        let gramsPerTroyOz = 31.1035
        let perGramPureCAD = gold.price / gramsPerTroyOz * fx.price
        let value = perGramPureCAD * (10.0 / 24.0)   // 10K purity
        return WidgetRow(symbol: "Gold 10K", fullSymbol: "GC=F", name: "Per gram · CAD",
                         price: value, changePercent: gold.changePercent, isUp: gold.isUp,
                         hasData: true, score: nil, band: nil)
    }

    static func loadEntry(limit: Int) async -> StockEntry {
        async let moodTask = loadMood()
        async let goldTask = loadGoldRow()

        // Reserve one slot for the gold row.
        let stockLimit = max(limit - 1, 1)
        let items = Array(WatchlistStore.widgetSymbols.prefix(stockLimit))
        guard !items.isEmpty else {
            var rows: [WidgetRow] = []
            if let gold = await goldTask { rows.append(gold) }
            return StockEntry(date: Date(), rows: rows, isPlaceholder: false, mood: await moodTask)
        }

        // Fetch each symbol's year of daily data concurrently; derive the live
        // quote and the Stock Watcher Score (technical-based in the widget so it
        // stays fast and reliable — fundamentals are best-effort in the app).
        let rowsBySymbol = await withTaskGroup(of: (String, WidgetRow).self) { group -> [String: WidgetRow] in
            for item in items {
                group.addTask {
                    let display = item.symbol
                        .replacingOccurrences(of: ".TO", with: "")
                        .replacingOccurrences(of: ".V", with: "")
                    let niceName = TSXCatalog.name(for: item.symbol) ?? item.name

                    guard let result = try? await YahooService.shared.fetchCandles(symbol: item.symbol, range: .oneYear),
                          !result.candles.isEmpty else {
                        return (item.symbol, WidgetRow(symbol: display, fullSymbol: item.symbol, name: niceName, price: 0,
                                                       changePercent: 0, isUp: true, hasData: false,
                                                       score: nil, band: nil))
                    }
                    let quote = YahooService.quote(from: result.meta, fallbackSymbol: item.symbol)
                    let rating = TechnicalAnalyzer.analyze(result.candles)
                    let composite = CompositeEvaluator.evaluate(technical: rating,
                                                                fundamentals: Fundamentals(),
                                                                quote: quote)
                    return (item.symbol, WidgetRow(symbol: display, fullSymbol: item.symbol, name: niceName, price: quote.price,
                                                   changePercent: quote.changePercent, isUp: quote.isUp,
                                                   hasData: true, score: composite?.score, band: composite?.band))
                }
            }
            var dict: [String: WidgetRow] = [:]
            for await (symbol, row) in group { dict[symbol] = row }
            return dict
        }

        var rows = items.compactMap { rowsBySymbol[$0.symbol] }
        if let gold = await goldTask { rows.append(gold) }
        return StockEntry(date: Date(), rows: rows, isPlaceholder: false, mood: await moodTask)
    }
}
