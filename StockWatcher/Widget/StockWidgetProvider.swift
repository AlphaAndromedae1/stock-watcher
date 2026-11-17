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
    var id: String { symbol }
}

struct StockEntry: TimelineEntry {
    let date: Date
    let rows: [WidgetRow]
    let isPlaceholder: Bool

    static let sample = StockEntry(
        date: Date(),
        rows: [
            WidgetRow(symbol: "RY", name: "Royal Bank", price: 176.42, changePercent: 0.82, isUp: true, hasData: true),
            WidgetRow(symbol: "SHOP", name: "Shopify", price: 148.10, changePercent: -1.35, isUp: false, hasData: true),
            WidgetRow(symbol: "ENB", name: "Enbridge", price: 59.73, changePercent: 0.41, isUp: true, hasData: true),
            WidgetRow(symbol: "CNQ", name: "Cdn Natural", price: 47.88, changePercent: -0.22, isUp: false, hasData: true)
        ],
        isPlaceholder: true)
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
        case .systemMedium: return 4
        case .systemLarge: return 8
        case .accessoryRectangular: return 2
        default: return 3
        }
    }

    static func loadEntry(limit: Int) async -> StockEntry {
        let items = Array(WatchlistStore.shared.load().prefix(limit))
        guard !items.isEmpty else {
            return StockEntry(date: Date(), rows: [], isPlaceholder: false)
        }
        let quotes = await YahooService.shared.fetchQuotes(symbols: items.map(\.symbol))
        let rows: [WidgetRow] = items.map { item in
            let display = item.symbol
                .replacingOccurrences(of: ".TO", with: "")
                .replacingOccurrences(of: ".V", with: "")
            if let q = quotes.first(where: { $0.symbol == item.symbol }) {
                return WidgetRow(symbol: display, name: q.shortName ?? item.name,
                                 price: q.price, changePercent: q.changePercent,
                                 isUp: q.isUp, hasData: true)
            } else {
                return WidgetRow(symbol: display, name: item.name,
                                 price: 0, changePercent: 0, isUp: true, hasData: false)
            }
        }
        return StockEntry(date: Date(), rows: rows, isPlaceholder: false)
    }
}
