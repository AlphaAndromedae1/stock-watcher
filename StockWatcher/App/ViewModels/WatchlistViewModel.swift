import Foundation
import Combine
import WidgetKit

struct PortfolioSummary {
    let marketValue: Double
    let cost: Double
    let count: Int
    var gain: Double { marketValue - cost }
    var gainPercent: Double { cost > 0 ? gain / cost * 100 : 0 }
}

@MainActor
final class WatchlistViewModel: ObservableObject {
    @Published var items: [WatchItem] = []
    @Published var quotes: [String: Quote] = [:]
    @Published var isLoading = false
    @Published var lastUpdated: Date?

    /// Combined gain/loss across holdings that currently have a quote.
    var portfolio: PortfolioSummary? {
        let holdings = HoldingsStore.shared.all()
        guard !holdings.isEmpty else { return nil }
        var marketValue = 0.0
        var cost = 0.0
        var count = 0
        for h in holdings {
            guard let q = quotes[h.symbol], q.price > 0 else { continue }
            marketValue += h.marketValue(at: q.price)
            cost += h.cost
            count += 1
        }
        guard count > 0, cost > 0 else { return nil }
        return PortfolioSummary(marketValue: marketValue, cost: cost, count: count)
    }

    private let store = WatchlistStore.shared
    private let service = YahooService.shared

    private let cacheKey = "watchlist.quotes"

    func onAppear() {
        items = store.load()
        if quotes.isEmpty {
            // Show last-known quotes instantly (also works offline), then refresh.
            if let cached = DataCache.shared.load([String: Quote].self, key: cacheKey) {
                quotes = cached
            }
            Task { await refresh() }
        }
    }

    func refresh() async {
        items = store.load()
        guard !items.isEmpty else { quotes = [:]; return }
        isLoading = true
        let results = await service.fetchQuotes(symbols: items.map(\.symbol))
        for q in results { quotes[q.symbol] = q }
        if !results.isEmpty {
            DataCache.shared.save(quotes, key: cacheKey)
            lastUpdated = Date()
        }
        isLoading = false
    }

    func contains(_ symbol: String) -> Bool {
        items.contains { $0.symbol == symbol.uppercased() }
    }

    func add(_ item: WatchItem) {
        items = store.add(item)
        reloadWidgets()
        Task { await refresh() }
    }

    func remove(atOffsets offsets: IndexSet) {
        let symbols = offsets.map { items[$0].symbol }
        for s in symbols { items = store.remove(symbol: s); quotes[s] = nil }
        reloadWidgets()
    }

    func remove(symbol: String) {
        items = store.remove(symbol: symbol)
        quotes[symbol] = nil
        reloadWidgets()
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        store.save(items)
        reloadWidgets()
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
