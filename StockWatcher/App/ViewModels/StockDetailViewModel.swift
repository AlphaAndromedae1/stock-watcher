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
    @Published var profile: StockProfile?
    @Published var composite: CompositeEvaluator.Result?
    @Published var range: ChartRange = .oneYear

    @Published var isLoadingChart = false
    @Published var isLoadingRating = false
    @Published var errorMessage: String?
    @Published var holding: Holding?
    @Published var scoreHistory: [ScoreSample] = []
    @Published var news: [NewsItem] = []
    @Published var newsTone: NewsTone?
    @Published var sim: MonteCarloResult?
    @Published var simHorizon: Int = 63      // 21=1M, 63=3M, 252=1Y

    private var ratingCandles: [Candle] = []

    private let service = YahooService.shared

    init(symbol: String, name: String) {
        self.symbol = symbol
        self.name = name
        self.range = SettingsStore.shared.defaultRange
        self.holding = HoldingsStore.shared.holding(symbol: symbol)
        self.scoreHistory = ScoreHistoryStore.shared.history(symbol: symbol)
    }

    func saveHolding(shares: Double, costBasis: Double) {
        if shares > 0 {
            let h = Holding(symbol: symbol, shares: shares, costBasis: costBasis)
            HoldingsStore.shared.save(h)
            holding = h
        } else {
            HoldingsStore.shared.remove(symbol: symbol)
            holding = nil
        }
    }

    func removeHolding() {
        HoldingsStore.shared.remove(symbol: symbol)
        holding = nil
    }

    private func candleCacheKey(_ range: ChartRange) -> String {
        "candles.\(symbol).\(range.rawValue)"
    }

    func loadAll() async {
        async let chart: Void = loadChart()
        async let analysis: Void = loadRatingAndFundamentals()
        async let newsLoad: Void = loadNews()
        await chart
        await analysis
        await newsLoad
    }

    func loadNews() async {
        news = await NewsService.shared.fetch(symbol: symbol)
        newsTone = NewsSentiment.analyze(news)
    }

    func setRange(_ newRange: ChartRange) {
        guard newRange != range else { return }
        range = newRange
        Task { await loadChart() }
    }

    func loadChart() async {
        isLoadingChart = true
        defer { isLoadingChart = false }
        // Show cached candles instantly (also offline) while fresh data loads.
        if chartCandles.isEmpty,
           let cached = DataCache.shared.load([Candle].self, key: candleCacheKey(range)) {
            chartCandles = cached
        }
        do {
            let (candles, meta) = try await service.fetchCandles(symbol: symbol, range: range)
            chartCandles = candles
            quote = YahooService.quote(from: meta, fallbackSymbol: symbol)
            errorMessage = nil
            if !candles.isEmpty {
                DataCache.shared.save(candles, key: candleCacheKey(range))
            }
        } catch {
            if chartCandles.isEmpty {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func loadRatingAndFundamentals() async {
        isLoadingRating = true
        defer { isLoadingRating = false }
        do {
            // Ratings always use ~1 year of daily bars so long MAs are defined.
            let (candles, meta) = try await service.fetchCandles(symbol: symbol, range: .oneYear)
            rating = TechnicalAnalyzer.analyze(candles)
            ratingCandles = candles
            if quote == nil { quote = YahooService.quote(from: meta, fallbackSymbol: symbol) }
        } catch {
            if errorMessage == nil {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }

        // Best-effort fundamentals + profile (never throw).
        let f = await service.fetchFundamentals(symbol: symbol)
        fundamentals = f
        fundamentalChecks = FundamentalAnalyzer.evaluate(f)
        healthScore = FundamentalAnalyzer.healthScore(f)
        profile = await service.fetchProfile(symbol: symbol)

        // Custom Stock Watcher Score blends everything we have (user-tunable weights).
        composite = CompositeEvaluator.evaluate(technical: rating, fundamentals: f, quote: quote,
                                                weights: SettingsStore.shared.weights)

        // Record the score over time so we can show its trend.
        if let c = composite {
            ScoreHistoryStore.shared.record(symbol: symbol, score: c.score)
            scoreHistory = ScoreHistoryStore.shared.history(symbol: symbol)
        }

        await runSim()
    }

    func setSimHorizon(_ days: Int) {
        guard days != simHorizon else { return }
        simHorizon = days
        Task { await runSim() }
    }

    func runSim() async {
        guard !ratingCandles.isEmpty else { return }
        let candles = ratingCandles
        let horizon = simHorizon
        let plan = TradePlanStore.shared.plan(for: symbol)
        let result = await Task.detached(priority: .userInitiated) {
            MonteCarlo.simulate(candles: candles, horizonDays: horizon,
                                target: plan?.target, stop: plan?.stop)
        }.value
        sim = result
    }
}
