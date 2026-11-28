import Foundation

/// One of the nine Piotroski tests.
public struct PiotroskiTest: Equatable, Sendable, Identifiable {
    public enum Outcome: Equatable, Sendable {
        case pass
        case fail
        case unavailable
    }

    public let id: String
    public let title: String
    public let outcome: Outcome
    /// The numbers behind the test, e.g. "ROA 11.1% vs 10.0% a year earlier".
    public let detail: String

    public init(id: String, title: String, outcome: Outcome, detail: String) {
        self.id = id
        self.title = title
        self.outcome = outcome
        self.detail = detail
    }
}

public struct PiotroskiScore: Equatable, Sendable {
    /// Tests passed.
    public let score: Int
    /// Tests with enough history to be judged, out of nine.
    public let computable: Int
    public let tests: [PiotroskiTest]
    /// The fiscal year-end this score describes.
    public let latestYear: String

    public init(score: Int, computable: Int, tests: [PiotroskiTest], latestYear: String) {
        self.score = score
        self.computable = computable
        self.tests = tests
        self.latestYear = latestYear
    }
}

/// Piotroski's F-Score (2000): nine yes/no tests on the latest fiscal year,
/// compared with the year before. Informational only and never part of the
/// Stock Watcher Score. It uses no EBIT, so it doesn't depend on that definition.
public enum Piotroski {

    /// `years` must be newest first, as built by `AnnualYears.build`.
    public static func score(_ years: [AnnualYear]) -> PiotroskiScore? {
        guard let t = years.first else { return nil }
        let p: AnnualYear? = years.count > 1 ? years[1] : nil
        let pp: AnnualYear? = years.count > 2 ? years[2] : nil

        func num(_ y: AnnualYear?, _ key: String) -> Double? {
            y?.values[key]
        }

        // Return on beginning-of-year assets, as Piotroski defines ROA.
        func roa(_ y: AnnualYear?, begin: AnnualYear?) -> Double? {
            guard let ni = num(y, "annualNetIncome"), let ta = num(begin, "annualTotalAssets"), ta > 0 else {
                return nil
            }
            return ni / ta
        }

        func cfoOverAssets(_ y: AnnualYear?, begin: AnnualYear?) -> Double? {
            guard let cfo = num(y, "annualOperatingCashFlow"), let ta = num(begin, "annualTotalAssets"), ta > 0 else {
                return nil
            }
            return cfo / ta
        }

        // Total debt over average total assets (Piotroski uses long-term debt; total
        // debt is used so reclassified current debt still counts).
        func leverage(_ y: AnnualYear?, prior: AnnualYear?) -> Double? {
            guard let debt = num(y, "annualTotalDebt"),
                  let ta = num(y, "annualTotalAssets"),
                  let taPrior = num(prior, "annualTotalAssets") else {
                return nil
            }
            let average = (ta + taPrior) / 2
            guard average > 0 else { return nil }
            return debt / average
        }

        func currentRatio(_ y: AnnualYear?) -> Double? {
            guard let ca = num(y, "annualCurrentAssets"), let cl = num(y, "annualCurrentLiabilities"), cl > 0 else {
                return nil
            }
            return ca / cl
        }

        func grossMargin(_ y: AnnualYear?) -> Double? {
            guard let gp = num(y, "annualGrossProfit"), let rev = num(y, "annualTotalRevenue"), rev > 0 else {
                return nil
            }
            return gp / rev
        }

        func assetTurnover(_ y: AnnualYear?, begin: AnnualYear?) -> Double? {
            guard let rev = num(y, "annualTotalRevenue"), let ta = num(begin, "annualTotalAssets"), ta > 0 else {
                return nil
            }
            return rev / ta
        }

        func higher(_ a: Double?, _ b: Double?) -> Bool? {
            guard let a, let b else { return nil }
            return a > b
        }

        func lower(_ a: Double?, _ b: Double?) -> Bool? {
            guard let a, let b else { return nil }
            return a < b
        }

        func atMost(_ a: Double?, _ b: Double?) -> Bool? {
            guard let a, let b else { return nil }
            return a <= b
        }

        func pct(_ v: Double?) -> String { Fmt.percentFromFraction(v, decimals: 1) }
        func ratio(_ v: Double?) -> String { Fmt.number(v, decimals: 2) }
        func money(_ v: Double?) -> String { Fmt.bigNumber(v) }

        func make(_ id: String, _ title: String, _ pass: Bool?, _ detail: String) -> PiotroskiTest {
            guard let pass else {
                return PiotroskiTest(id: id, title: title, outcome: .unavailable,
                                     detail: "Needs more years of history")
            }
            return PiotroskiTest(id: id, title: title, outcome: pass ? .pass : .fail, detail: detail)
        }

        let roaNow = roa(t, begin: p)
        let roaPrior = roa(p, begin: pp)
        let cfoNow = num(t, "annualOperatingCashFlow")
        let cfoScaledNow = cfoOverAssets(t, begin: p)
        let levNow = leverage(t, prior: p)
        let levPrior = leverage(p, prior: pp)
        let crNow = currentRatio(t)
        let crPrior = currentRatio(p)
        let gmNow = grossMargin(t)
        let gmPrior = grossMargin(p)
        let atNow = assetTurnover(t, begin: p)
        let atPrior = assetTurnover(p, begin: pp)
        let sharesNow = num(t, "annualDilutedAverageShares")
        let sharesPrior = num(p, "annualDilutedAverageShares")

        let t1 = make("profitability", "Return on assets is positive", roaNow.map { $0 > 0 },
                      "ROA \(pct(roaNow)) on beginning-of-year assets")
        let t2 = make("cashflow", "Operating cash flow is positive", cfoNow.map { $0 > 0 },
                      "Operating cash flow \(money(cfoNow))")
        let t3 = make("roa-up", "ROA improved", higher(roaNow, roaPrior),
                      "ROA \(pct(roaNow)) vs \(pct(roaPrior)) a year earlier")
        let t4 = make("accrual", "Cash flow exceeds earnings", higher(cfoScaledNow, roaNow),
                      "Operating cash flow \(pct(cfoScaledNow)) of beginning assets vs ROA \(pct(roaNow))")
        let t5 = make("leverage-down", "Leverage fell", lower(levNow, levPrior),
                      "Total debt to average assets \(pct(levNow)) vs \(pct(levPrior))")
        let t6 = make("liquidity-up", "Current ratio improved", higher(crNow, crPrior),
                      "Current ratio \(ratio(crNow)) vs \(ratio(crPrior))")
        let t7 = make("no-dilution", "No new shares issued", atMost(sharesNow, sharesPrior),
                      "Diluted shares \(money(sharesNow)) vs \(money(sharesPrior))")
        let t8 = make("margin-up", "Gross margin improved", higher(gmNow, gmPrior),
                      "Gross margin \(pct(gmNow)) vs \(pct(gmPrior))")
        let t9 = make("turnover-up", "Asset turnover improved", higher(atNow, atPrior),
                      "Asset turnover \(ratio(atNow)) vs \(ratio(atPrior))")

        let tests = [t1, t2, t3, t4, t5, t6, t7, t8, t9]
        let passed = tests.filter { $0.outcome == .pass }.count
        let computable = tests.filter { $0.outcome != .unavailable }.count
        return PiotroskiScore(score: passed, computable: computable, tests: tests, latestYear: t.asOf)
    }
}
