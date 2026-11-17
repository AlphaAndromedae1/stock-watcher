import Foundation
import Combine

@MainActor
final class StockDetailViewModel: ObservableObject {
    let symbol: String
    let name: String

    @Published var quote: Quote?
    @Published var chartCandles: [Candle] = []
    @Published var rating: TechnicalRating?
    @Published var fundamentals = Fundamentals()
    @Published var fundamentalChecks: [FundamentalAnalyzer.Check] = []
    @Published var healthScore: Int?
    @Published var range: ChartRange = .oneYear

    @Published var isLoadingChart = false
    @Published var isLoadingRating = false
    @Published var errorMessage: String?

    private let service = YahooService.shared

    init(symbol: String, name: String) {
        self.symbol = symbol
        self.name = name
    }

    func loadAll() async {
        async let chart: Void = loadChart()
        async let analysis: Void = loadRatingAndFundamentals()
        await chart
        await analysis
    }

    func setRange(_ newRange: ChartRange) {
        guard newRange != range else { return }
        range = newRange
        Task { await loadChart() }
    }

    func loadChart() async {
        isLoadingChart = true
        defer { isLoadingChart = false }
        do {
            let (candles, meta) = try await service.fetchCandles(symbol: symbol, range: range)
            chartCandles = candles
            quote = YahooService.quote(from: meta, fallbackSymbol: symbol)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadRatingAndFundamentals() async {
        isLoadingRating = true
        defer { isLoadingRating = false }
        do {
            // Ratings always use ~1 year of daily bars so long MAs are defined.
            let (candles, meta) = try await service.fetchCandles(symbol: symbol, range: .oneYear)
            rating = TechnicalAnalyzer.analyze(candles)
            if quote == nil { quote = YahooService.quote(from: meta, fallbackSymbol: symbol) }
        } catch {
            if errorMessage == nil {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }

        // Best-effort fundamentals (never throws).
        let f = await service.fetchFundamentals(symbol: symbol)
        fundamentals = f
        fundamentalChecks = FundamentalAnalyzer.evaluate(f)
        healthScore = FundamentalAnalyzer.healthScore(f)
    }
}
