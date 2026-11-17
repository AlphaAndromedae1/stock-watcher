import XCTest
// The Shared sources are compiled directly into this test target, so the
// analysis types are available without importing the app module.

final class AnalysisTests: XCTestCase {

    // MARK: helpers

    /// Build daily candles from a close-price series (H/L padded around close).
    private func candles(from closes: [Double]) -> [Candle] {
        var day = Date(timeIntervalSince1970: 1_600_000_000)
        return closes.map { c in
            defer { day = day.addingTimeInterval(86_400) }
            return Candle(date: day, open: c, high: c * 1.01, low: c * 0.99, close: c, volume: 1_000_000)
        }
    }

    // MARK: indicator math

    func testSMA() {
        let s = Indicators.sma([1, 2, 3, 4, 5], 5)
        XCTAssertEqual(s.last ?? .nan, 3.0, accuracy: 1e-9)
    }

    func testSMARolling() {
        let s = Indicators.sma([2, 4, 6, 8], 2)
        XCTAssertTrue(s[0].isNaN)
        XCTAssertEqual(s[1], 3, accuracy: 1e-9)
        XCTAssertEqual(s[3], 7, accuracy: 1e-9)
    }

    func testEMAApproxLast() {
        // EMA of a constant series equals the constant.
        let s = Indicators.ema(Array(repeating: 10.0, count: 50), 10)
        XCTAssertEqual(Indicators.lastFinite(s) ?? .nan, 10, accuracy: 1e-6)
    }

    func testRSIAllGainsIsHundred() {
        let rising = (1...60).map { Double($0) }
        let r = Indicators.rsi(rising, 14)
        XCTAssertEqual(Indicators.lastFinite(r) ?? 0, 100, accuracy: 1e-6)
    }

    func testRSIAllLossesIsZero() {
        let falling = (1...60).map { Double(61 - $0) }
        let r = Indicators.rsi(falling, 14)
        XCTAssertEqual(Indicators.lastFinite(r) ?? 100, 0, accuracy: 1e-6)
    }

    func testMACDHasSignal() {
        let series = (1...100).map { 100 + 10 * sin(Double($0) / 5) }
        let m = Indicators.macd(series)
        XCTAssertNotNil(Indicators.lastFinite(m.signal))
    }

    // MARK: aggregation

    func testRecommendationThresholds() {
        XCTAssertEqual(Recommendation.from(average: 0.8), .strongBuy)
        XCTAssertEqual(Recommendation.from(average: 0.2), .buy)
        XCTAssertEqual(Recommendation.from(average: 0.0), .neutral)
        XCTAssertEqual(Recommendation.from(average: -0.2), .sell)
        XCTAssertEqual(Recommendation.from(average: -0.8), .strongSell)
    }

    func testUptrendIsBullish() {
        let closes = (0..<300).map { 50 + Double($0) * 0.5 }  // steady uptrend
        let rating = TechnicalAnalyzer.analyze(candles(from: closes))
        // Price is above every moving average in a sustained uptrend.
        XCTAssertEqual(rating.movingAverages.recommendation, .strongBuy)
        XCTAssertGreaterThan(rating.summaryAverage, 0.1)
        XCTAssertTrue(rating.summary == .buy || rating.summary == .strongBuy)
    }

    func testDowntrendIsBearish() {
        let closes = (0..<300).map { 200 - Double($0) * 0.5 }  // steady downtrend
        let rating = TechnicalAnalyzer.analyze(candles(from: closes))
        XCTAssertEqual(rating.movingAverages.recommendation, .strongSell)
        XCTAssertLessThan(rating.summaryAverage, -0.1)
    }

    func testInsufficientDataSkipsLongMAs() {
        let closes = (0..<30).map { 100 + Double($0) }  // not enough for SMA200
        let rating = TechnicalAnalyzer.analyze(candles(from: closes))
        XCTAssertFalse(rating.movingAverages.results.contains { $0.name == "SMA (200)" })
    }

    func testFundamentalHealthScoreRange() {
        var f = Fundamentals()
        f.trailingPE = 15
        f.profitMargin = 0.2
        f.returnOnEquity = 0.25
        f.debtToEquity = 40
        f.revenueGrowth = 0.12
        let score = FundamentalAnalyzer.healthScore(f)
        XCTAssertNotNil(score)
        if let score { XCTAssertTrue((0...100).contains(score)) }
    }
}
