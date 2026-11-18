import Foundation
import Combine

/// Scans the TSX catalog's technical ratings and ranks them to surface
/// algorithmic "recommended buys", and loads the overall market mood.
@MainActor
final class IdeasViewModel: ObservableObject {

    struct Idea: Identifiable, Sendable {
        let entry: TSXCatalog.Entry
        let quote: Quote?
        let rating: TechnicalRating
        var id: String { entry.symbol }
        var average: Double { rating.summaryAverage }
        var recommendation: Recommendation { rating.summary }
    }

    @Published var mood: MarketMood?
    @Published var ideas: [Idea] = []          // sorted best-first
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var lastUpdated: Date?

    private let service = YahooService.shared
    private var hasLoaded = false

    /// Stocks our ranking rates as buys, best-first.
    var recommendedBuys: [Idea] {
        ideas.filter { $0.recommendation == .buy || $0.recommendation == .strongBuy }
    }

    func onAppear() {
        if !hasLoaded { Task { await refresh() } }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        progress = 0
        defer { isLoading = false; hasLoaded = true; lastUpdated = Date() }

        async let moodTask = StockMood.load()
        await scan()
        mood = await moodTask
    }

    private func scan() async {
        let universe = TSXCatalog.all
        let total = max(universe.count, 1)
        var collected: [Idea] = []
        let chunkSize = 6
        var index = 0

        while index < universe.count {
            let upper = min(index + chunkSize, universe.count)
            let chunk = Array(universe[index..<upper])
            let batch = await withTaskGroup(of: Idea?.self) { group -> [Idea] in
                for entry in chunk {
                    group.addTask { await Self.evaluate(entry) }
                }
                var out: [Idea] = []
                for await result in group {
                    if let result { out.append(result) }
                }
                return out
            }
            collected.append(contentsOf: batch)
            index = upper
            progress = Double(index) / Double(total)
        }

        ideas = collected.sorted { $0.average > $1.average }
    }

    /// Runs off the main actor (nonisolated, touches no isolated state).
    private nonisolated static func evaluate(_ entry: TSXCatalog.Entry) async -> Idea? {
        guard let result = try? await YahooService.shared.fetchCandles(symbol: entry.symbol, range: .oneYear),
              !result.candles.isEmpty else { return nil }
        let rating = TechnicalAnalyzer.analyze(result.candles)
        let quote = YahooService.quote(from: result.meta, fallbackSymbol: entry.symbol)
        return Idea(entry: entry, quote: quote, rating: rating)
    }
}

/// Small helper to load the market mood from the two volatility indexes.
enum StockMood {
    static func load() async -> MarketMood? {
        let vix = try? await YahooService.shared.fetchQuote(symbol: "^VIX")
        let vixc = try? await YahooService.shared.fetchQuote(symbol: "^VIXC")
        guard vix != nil || vixc != nil else { return nil }
        return MarketMood(vix: vix?.price, vixChangePercent: vix?.changePercent,
                          vixc: vixc?.price, asOf: Date())
    }
}
