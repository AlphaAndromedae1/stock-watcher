import Foundation
import XCTest
// Shared sources are compiled directly into this test target.

final class AltmanTests: XCTestCase {

    private func year(_ asOf: String, ca: Double, cl: Double, ta: Double, re: Double,
                      equity: Double, liabilities: Double, pretax: Double?, interest: Double?,
                      other: Double? = nil) -> AnnualYear {
        var values: [String: Double] = [
            "annualCurrentAssets": ca,
            "annualCurrentLiabilities": cl,
            "annualTotalAssets": ta,
            "annualRetainedEarnings": re,
            "annualStockholdersEquity": equity,
            "annualTotalLiabilitiesNetMinorityInterest": liabilities
        ]
        if let pretax { values["annualPretaxIncome"] = pretax }
        if let interest { values["annualInterestExpense"] = interest }
        if let other { values["annualOtherIncomeExpense"] = other }
        return AnnualYear(asOf: asOf, values: values)
    }

    /// Hand-worked: X1 = 0.3, X2 = 0.2, X3 = 0.1, X4 = 1.5.
    /// Z = 6.56(0.3) + 3.26(0.2) + 6.72(0.1) + 1.05(1.5) = 4.867, which is safe.
    func testSafeZone() {
        let y = year("2025-12-31", ca: 50, cl: 20, ta: 100, re: 20, equity: 60, liabilities: 40,
                     pretax: 9, interest: 1)
        let z = Altman.zScore([y])
        XCTAssertEqual(z?.z ?? -1, 4.867, accuracy: 1e-6)
        XCTAssertEqual(z?.zone, AltmanZone.safe)
        XCTAssertEqual(z?.ebit ?? -1, 10, accuracy: 1e-9)
        XCTAssertEqual(z?.flagged, false)
    }

    /// Hand-worked: X1 = 0.1, X2 = 0.1, X3 = 0.05, X4 = 2/3.
    /// Z = 0.656 + 0.326 + 0.336 + 0.7 = 2.018, which is grey.
    func testGreyZone() {
        let y = year("2025-12-31", ca: 30, cl: 20, ta: 100, re: 10, equity: 40, liabilities: 60,
                     pretax: 4, interest: 1)
        let z = Altman.zScore([y])
        XCTAssertEqual(z?.z ?? -1, 2.018, accuracy: 1e-6)
        XCTAssertEqual(z?.zone, AltmanZone.grey)
    }

    /// Hand-worked: X1 = -0.4, X2 = -0.5, X3 = 0, X4 = 5/95.
    /// Z is about -4.199, which is distress.
    func testDistressZone() {
        let y = year("2025-12-31", ca: 10, cl: 50, ta: 100, re: -50, equity: 5, liabilities: 95,
                     pretax: -5, interest: 5)
        let z = Altman.zScore([y])
        XCTAssertEqual(z?.z ?? 0, -4.1987368, accuracy: 1e-6)
        XCTAssertEqual(z?.zone, AltmanZone.distress)
    }

    /// Other income of 3 against EBIT of 10 is 30%, above the 20% threshold.
    func testLargeOtherIncomeFlagsTheReading() {
        let y = year("2025-12-31", ca: 50, cl: 20, ta: 100, re: 20, equity: 60, liabilities: 40,
                     pretax: 9, interest: 1, other: 3)
        let z = Altman.zScore([y])
        XCTAssertEqual(z?.flagged, true)
        XCTAssertEqual(z?.otherIncomeShare ?? -1, 0.3, accuracy: 1e-9)
    }

    /// No interest expense for the latest year means no EBIT, so no score.
    func testMissingInterestGivesNoScore() {
        let y = year("2025-12-31", ca: 50, cl: 20, ta: 100, re: 20, equity: 60, liabilities: 40,
                     pretax: 9, interest: nil)
        XCTAssertNil(Altman.zScore([y]))
    }
}
