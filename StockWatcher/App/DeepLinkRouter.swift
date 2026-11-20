import Foundation
import Combine

struct DeepLink: Hashable, Identifiable {
    let symbol: String
    let name: String
    var id: String { symbol }
}

/// Routes `stockwatcher://` deep links (from widgets) to a stock detail screen.
@MainActor
final class DeepLinkRouter: ObservableObject {
    @Published var target: DeepLink?

    func handle(_ url: URL) {
        guard let symbol = StockWatcherURL.symbol(from: url) else { return }
        let name = TSXCatalog.name(for: symbol) ?? symbol
        target = DeepLink(symbol: symbol.uppercased(), name: name)
    }
}
