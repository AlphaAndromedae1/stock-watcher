import Foundation
import XCTest
// Shared sources are compiled directly into this test target.

final class PiotroskiTests: XCTestCase {

    private func year(_ asOf: String, ni: Double, ta: Double, cfo: Double, debt: Double,
                      ca: Double, cl: Double, shares: Double, rev: Double, gp: Double) -> AnnualYear {
        AnnualYear(asOf: asOf, values: [
            "annualNetIncome": ni,
            "annualTotalAssets": ta,
            "annualOperatingCashFlow": cfo,
            "annualTotalDebt": debt,
            "annualCurrentAssets": ca,
            "annualCurrentLiabilities": cl,
            "annualDilutedAverageShares": shares,
            "annualTotalRevenue": rev,
            "annualGrossProfit": gp
        ])
    }

    /// Hand-worked example. Asset turnover falls (200/90 = 2.22 vs 180/80 = 2.25),
    /// and every other test passes, so the score is 8 of 9.
    func testFullHistoryScoresEightOfNine() {
        let t = year("2025-12-31", ni: 10, ta: 100, cfo: 15, debt: 20, ca: 30, cl: 20,
                     shares: 100, rev: 200, gp: 80)
        let p = year("2024-12-31", ni: 8, ta: 90, cfo: 12, debt: 25, ca: 25, cl: 20,
                     shares: 100, rev: 180, gp: 70)
        let pp = year("2023-12-31", ni: 6, ta: 80, cfo: 9, debt: 30, ca: 24, cl: 20,
                      shares: 105, rev: 160, gp: 56)

        let score = Piotroski.score([t, p, pp])
        XCTAssertEqual(score?.score ?? -1, 8)
        XCTAssertEqual(score?.computable ?? -1, 9)
        XCTAssertEqual(score?.latestYear, "2025-12-31")

        let turnover = score?.tests.first(where: { $0.id == "turnover-up" })
        XCTAssertEqual(turnover?.outcome, PiotroskiTest.Outcome.fail)
    }

    /// With only two years, the three tests that need a third year drop out:
    /// ROA change, leverage change and asset-turnover change.
    func testTwoYearsLeavesThreeTestsUnavailable() {
        let t = year("2025-12-31", ni: 10, ta: 100, cfo: 15, debt: 20, ca: 30, cl: 20,
                     shares: 100, rev: 200, gp: 80)
        let p = year("2024-12-31", ni: 8, ta: 90, cfo: 12, debt: 25, ca: 25, cl: 20,
                     shares: 100, rev: 180, gp: 70)

        let score = Piotroski.score([t, p])
        XCTAssertEqual(score?.computable ?? -1, 6)
        XCTAssertEqual(score?.score ?? -1, 6)
    }

    func testNoYearsGivesNoScore() {
        XCTAssertNil(Piotroski.score([]))
    }

    func testBuildAlignsFieldsByYearEnd() {
        let series: [String: [AnnualPoint]] = [
            "annualNetIncome": [AnnualPoint(asOfDate: "2025-12-31", value: 1),
                                AnnualPoint(asOfDate: "2024-12-31", value: 2)],
            "annualTotalDebt": [AnnualPoint(asOfDate: "2025-12-31", value: 5)]
        ]
        let years = AnnualYears.build(series)
        XCTAssertEqual(years.count, 2)
        XCTAssertEqual(years[0].asOf, "2025-12-31")
        XCTAssertEqual(years[0].values["annualTotalDebt"], 5)
        XCTAssertNil(years[1].values["annualTotalDebt"])
    }
}
