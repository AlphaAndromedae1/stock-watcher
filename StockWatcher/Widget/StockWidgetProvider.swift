import WidgetKit
import SwiftUI

/// One row shown in the widget.
struct WidgetRow: Identifiable, Hashable {
    let symbol: String        // display symbol, e.g. "RY"
    let name: String
    let price: Double
    let changePercent: Double
    let isUp: Bool
    let hasData: Bool
    let score: Int?                       // Stock Watcher Score 0…100
    let band: CompositeEvaluator.Band?
    var id: String { symbol }
}

struct StockEntry: TimelineEntry {
    let date: Date
    let rows: [WidgetRow]
    let isPlaceholder: Bool
    let mood: MarketMood?

    static let sample = StockEntry(
        date: Date(),
        rows: [
            WidgetRow(symbol: "RY", name: "Royal Bank of Canada", price: 176.42, changePercent: 0.82, isUp: true, hasData: true, score: 74, band: .bullish),
            WidgetRow(symbol: "SHOP", name: "Shopify Inc.", price: 148.10, changePercent: -1.35, isUp: false, hasData: true, score: 48, band: .mixed),
            WidgetRow(symbol: "ENB", name: "Enbridge Inc.", price: 59.73, changePercent: 0.41, isUp: true, hasData: true, score: 63, band: .bullish),
            WidgetRow(symbol: "CNQ", name: "Canadian Natural", price: 47.88, changePercent: -0.22, isUp: false, hasData: true, score: 39, band: .bearish)
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
            // Refresh roughly every 30 minutes; WidgetKit coalesces as needed.
            let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
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

    static func loadEntry(limit: Int) async -> StockEntry {
        async let moodTask = loadMood()

        let items = Array(WatchlistStore.shared.load().prefix(limit))
        guard !items.isEmpty else {
            return StockEntry(date: Date(), rows: [], isPlaceholder: false, mood: await moodTask)
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
                        return (item.symbol, WidgetRow(symbol: display, name: niceName, price: 0,
                                                       changePercent: 0, isUp: true, hasData: false,
                                                       score: nil, band: nil))
                    }
                    let quote = YahooService.quote(from: result.meta, fallbackSymbol: item.symbol)
                    let rating = TechnicalAnalyzer.analyze(result.candles)
                    let composite = CompositeEvaluator.evaluate(technical: rating,
                                                                fundamentals: Fundamentals(),
                                                                quote: quote)
                    return (item.symbol, WidgetRow(symbol: display, name: niceName, price: quote.price,
                                                   changePercent: quote.changePercent, isUp: quote.isUp,
                                                   hasData: true, score: composite?.score, band: composite?.band))
                }
            }
            var dict: [String: WidgetRow] = [:]
            for await (symbol, row) in group { dict[symbol] = row }
            return dict
        }

        let rows = items.compactMap { rowsBySymbol[$0.symbol] }
        return StockEntry(date: Date(), rows: rows, isPlaceholder: false, mood: await moodTask)
    }
}
