import Foundation
import XCTest
// Shared sources are compiled directly into this test target.

final class MagicFormulaTests: XCTestCase {

    private func inputs(_ symbol: String, price: Double, shares: Double, ebit: Double,
                        debt: Double = 0, cash: Double = 0, ca: Double, cl: Double,
                        currentDebt: Double = 0, ppe: Double) -> MagicInputs {
        MagicInputs(symbol: symbol, name: symbol, statementsAvailable: true, price: price,
                    dilutedShares: shares, ebit: ebit, totalDebt: debt, cash: cash,
                    currentAssets: ca, currentLiabilities: cl, currentDebt: currentDebt,
                    netPPE: ppe)
    }

    /// Hand-worked:
    /// A: market cap 100, EV 100, yield 20/100 = 0.20; capital 20 + 30 = 50, return 0.40.
    /// B: market cap 100, EV 100 + 50 - 10 = 140, yield 30/140 = 0.214;
    ///    capital (40 - 10) - 20 + 40 = 50, return 0.60.
    /// C: market cap 500, EV 500, yield 0.05; capital 0 + 10 = 10, return 2.50.
    /// Yield ranks: B 1, A 2, C 3. Return ranks: C 1, B 2, A 3.
    /// Combined sums: A 5, B 3, C 4, so the order is B, C, A.
    func testRankCombinesEarningsYieldAndReturnOnCapital() {
        let items = [
            inputs("A", price: 10, shares: 10, ebit: 20, ca: 50, cl: 30, ppe: 30),
            inputs("B", price: 10, shares: 10, ebit: 30, debt: 50, cash: 10, ca: 40, cl: 20, ppe: 40),
            inputs("C", price: 5, shares: 100, ebit: 25, ca: 20, cl: 20, ppe: 10)
        ]
        let ranking = MagicFormula.rank(items, savedAt: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(ranking.rows.map(\.symbol), ["B", "C", "A"])
        XCTAssertEqual(ranking.rows.map(\.rank), [1, 2, 3])

        let a = ranking.rows.first { $0.symbol == "A" }
        XCTAssertEqual(a?.yieldRank, 2)
        XCTAssertEqual(a?.capitalRank, 3)
        XCTAssertEqual(a?.returnOnCapital ?? -1, 0.4, accuracy: 1e-9)

        let b = ranking.rows.first { $0.symbol == "B" }
        XCTAssertEqual(b?.earningsYield ?? -1, 30.0 / 140.0, accuracy: 1e-9)
        XCTAssertEqual(b?.marketCap ?? -1, 100, accuracy: 1e-9)
    }

    func testExcludesNonPositiveEbitAndMissingStatements() {
        let items = [
            inputs("D", price: 10, shares: 10, ebit: -5, ca: 50, cl: 30, ppe: 30),
            MagicInputs(symbol: "E", name: "E", statementsAvailable: false, price: 10,
                        dilutedShares: 10, ebit: 20, totalDebt: 0, cash: 0, currentAssets: 50,
                        currentLiabilities: 30, currentDebt: 0, netPPE: 30)
        ]
        let ranking = MagicFormula.rank(items)

        XCTAssertTrue(ranking.rows.isEmpty)
        XCTAssertEqual(ranking.excluded.map(\.symbol), ["D", "E"])
        XCTAssertEqual(ranking.excluded.first?.reason, "EBIT not positive")
        XCTAssertEqual(ranking.universeSize, 2)
    }

    /// Other income of 8 against EBIT of 20 is 40%, above the 20% threshold, so the name is
    /// excluded. Other income of 3 is 15%, so the name stays in the ranking. A U.S.-dollar
    /// statement against a Canadian price is excluded because it wasn't converted.
    func testExcludesInflatedEbitAndUnconvertedCurrency() {
        let inflated = MagicInputs(symbol: "G", name: "G", statementsAvailable: true, price: 10,
                                   dilutedShares: 10, ebit: 20, totalDebt: 0, cash: 0,
                                   currentAssets: 50, currentLiabilities: 30, currentDebt: 0,
                                   netPPE: 30, statementCurrency: "CAD", quoteCurrency: "CAD",
                                   otherIncome: 8)
        let modest = MagicInputs(symbol: "I", name: "I", statementsAvailable: true, price: 10,
                                 dilutedShares: 10, ebit: 20, totalDebt: 0, cash: 0,
                                 currentAssets: 50, currentLiabilities: 30, currentDebt: 0,
                                 netPPE: 30, statementCurrency: "CAD", quoteCurrency: "CAD",
                                 otherIncome: 3)
        let usd = MagicInputs(symbol: "H", name: "H", statementsAvailable: true, price: 10,
                              dilutedShares: 10, ebit: 20, totalDebt: 0, cash: 0,
                              currentAssets: 50, currentLiabilities: 30, currentDebt: 0,
                              netPPE: 30, statementCurrency: "USD", quoteCurrency: "CAD",
                              otherIncome: nil)

        let ranking = MagicFormula.rank([inflated, modest, usd])

        XCTAssertEqual(ranking.rows.map(\.symbol), ["I"])
        XCTAssertEqual(ranking.excluded.map(\.symbol), ["G", "H"])
        XCTAssertTrue(ranking.excluded.first?.reason.contains("40%") ?? false)
        XCTAssertEqual(ranking.excluded.last?.reason, "Statements in USD, price in CAD, not converted")
    }

    /// Greenblatt's universe here is the catalog minus financials: 73 catalog names
    /// less 14 banks and insurers, which is 59.
    func testUniverseIsTheFiftyNineNonFinancialNames() {
        let universe = MagicFormula.universe
        XCTAssertEqual(universe.count, 59)
        XCTAssertFalse(universe.contains { $0.sector == "Financials" })
        XCTAssertFalse(universe.contains { $0.symbol == "RY.TO" })
    }
}
