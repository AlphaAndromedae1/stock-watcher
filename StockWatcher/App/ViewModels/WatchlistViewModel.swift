import Foundation
import Combine
import WidgetKit

@MainActor
final class WatchlistViewModel: ObservableObject {
    @Published var items: [WatchItem] = []
    @Published var quotes: [String: Quote] = [:]
    @Published var isLoading = false
    @Published var lastUpdated: Date?

    private let store = WatchlistStore.shared
    private let service = YahooService.shared

    func onAppear() {
        items = store.load()
        if quotes.isEmpty { Task { await refresh() } }
    }

    func refresh() async {
        items = store.load()
        guard !items.isEmpty else { quotes = [:]; return }
        isLoading = true
        let results = await service.fetchQuotes(symbols: items.map(\.symbol))
        for q in results { quotes[q.symbol] = q }
        lastUpdated = Date()
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
