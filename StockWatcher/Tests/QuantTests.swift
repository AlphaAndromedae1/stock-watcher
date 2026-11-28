import Foundation
import XCTest
// Shared sources are compiled directly into this test target.

final class QuantTests: XCTestCase {

    private func candles(from closes: [Double], volume: Double = 1_000_000) -> [Candle] {
        var day = Date(timeIntervalSince1970: 1_600_000_000)
        return closes.map { c in
            defer { day = day.addingTimeInterval(86_400) }
            return Candle(date: day, open: c, high: c * 1.01, low: c * 0.99, close: c, volume: volume)
        }
    }

    // MARK: Graham

    func testGrahamNumberAndMargin() {
        // EPS = 20/10 = 2, book/share = 20/2 = 10 → √(22.5 × 2 × 10) = √450 ≈ 21.2132
        let g = QuantMetrics.graham(price: 20, trailingPE: 10, priceToBook: 2)
        XCTAssertNotNil(g)
        XCTAssertEqual(g?.value ?? .nan, 21.2132, accuracy: 1e-3)
        XCTAssertEqual(g?.marginOfSafety ?? .nan, 0.05719, accuracy: 1e-4)
    }

    func testGrahamNilForLossMakers() {
        XCTAssertNil(QuantMetrics.graham(price: 20, trailingPE: -5, priceToBook: 2))
    }

    // MARK: Sector P/E

    func testSectorMedianAndPremium() {
        let even = QuantMetrics.sectorValuation(ownPE: 20, peerPEs: [10, 15, 25, 30], sectorName: "Energy")
        XCTAssertEqual(even?.peerMedianPE ?? .nan, 20, accuracy: 1e-9)
        XCTAssertEqual(even?.premium ?? .nan, 0, accuracy: 1e-9)

        let flat = QuantMetrics.sectorValuation(ownPE: 20, peerPEs: [10, 10, 10], sectorName: "Energy")
        XCTAssertEqual(flat?.premium ?? .nan, 1.0, accuracy: 1e-9)

        XCTAssertNil(QuantMetrics.sectorValuation(ownPE: 20, peerPEs: [10, 12], sectorName: "Energy"))
    }

    func testPeersExcludeSelfAndStayInSector() {
        guard let p = QuantMetrics.peers(for: "RY.TO") else {
            XCTFail("expected peers for a catalog symbol")
            return
        }
        XCTAssertEqual(p.sector, "Financials")
        XCTAssertFalse(p.symbols.contains("RY.TO"))
        XCTAssertTrue(p.symbols.count >= 3)
    }

    // MARK: Momentum

    func testMomentumRendersOnOneYearWindow() {
        // Yahoo's 1-year window is ~252 bars. The strict 12-1 start would be out of
        // range, so the clamp must still produce a value.
        let closes = (0..<252).map { 100 * pow(1.001, Double($0)) }
        XCTAssertNotNil(QuantMetrics.momentum(closes))
        // Window runs from bar 0 to bar 230 (skipping the last 21 bars).
        XCTAssertEqual(QuantMetrics.momentum(closes) ?? .nan, pow(1.001, 230) - 1, accuracy: 1e-9)
    }

    // MARK: Risk

    func testDrawdowns() {
        let closes: [Double] = [100, 120, 60, 90]
        XCTAssertEqual(QuantMetrics.maxDrawdown(closes) ?? .nan, -0.5, accuracy: 1e-9)
        XCTAssertEqual(QuantMetrics.currentDrawdown(closes) ?? .nan, -0.25, accuracy: 1e-9)
    }

    func testConstantSeriesHasZeroVolatilityAndNoReturnPerRisk() {
        let closes = Array(repeating: 50.0, count: 40)
        XCTAssertEqual(QuantMetrics.volatility(closes) ?? .nan, 0, accuracy: 1e-12)
        XCTAssertNil(QuantMetrics.returnPerRisk(closes: closes, volatility: 0))
    }

    func testAverageDollarVolume() {
        let c = candles(from: Array(repeating: 10.0, count: 30), volume: 1_000_000)
        XCTAssertEqual(QuantMetrics.averageDollarVolume(c) ?? .nan, 10_000_000, accuracy: 1)
    }

    // MARK: Withholding

    func testWithholdingDragOnlyForUSDividendsInTFSA() {
        let tfsa = QuantMetrics.withholding(symbol: "AAPL", dividendYield: 0.04, account: .tfsa)
        XCTAssertEqual(tfsa?.drag ?? .nan, 0.006, accuracy: 1e-9)

        let rrsp = QuantMetrics.withholding(symbol: "AAPL", dividendYield: 0.04, account: .rrsp)
        XCTAssertEqual(rrsp?.drag ?? .nan, 0, accuracy: 1e-9)

        let canadian = QuantMetrics.withholding(symbol: "RY.TO", dividendYield: 0.04, account: .tfsa)
        XCTAssertEqual(canadian?.drag ?? .nan, 0, accuracy: 1e-9)

        XCTAssertNil(QuantMetrics.withholding(symbol: "AAPL", dividendYield: 0, account: .tfsa))
    }

    // MARK: Snapshot gating

    func testSnapshotHidesGrahamAndSectorForFunds() {
        let c = candles(from: (0..<260).map { 50 * pow(1.0005, Double($0)) })
        let s = QuantMetrics.snapshot(symbol: "XEQT.TO", candles: c, benchmark: nil,
                                      price: 50, trailingPE: 12, priceToBook: 2,
                                      dividendYield: 0.03, isOperatingCompany: false, isFund: true,
                                      sectorName: "Financials", peerPEs: [10, 15, 20],
                                      account: .nonRegistered)
        XCTAssertNil(s.graham)
        XCTAssertNil(s.sector)
        XCTAssertNotNil(s.momentum)
        XCTAssertNotNil(s.volatility)
        XCTAssertNotNil(s.withholding)
    }
}
