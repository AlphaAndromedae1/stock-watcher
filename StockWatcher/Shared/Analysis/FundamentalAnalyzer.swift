import Foundation

/// A transparent, rule-of-thumb read on a company's fundamentals. These are
/// *heuristics to prompt further research*, not precise fair-value models — the
/// right benchmark always depends on the sector. Each check explains itself.
public enum FundamentalAnalyzer {

    public enum Verdict: String, Codable, Sendable {
        case good, fair, weak, unknown
    }

    public struct Check: Identifiable, Equatable, Sendable {
        public let title: String
        public let verdict: Verdict
        public let detail: String
        public var id: String { title }
    }

    public static func evaluate(_ f: Fundamentals) -> [Check] {
        guard !f.isEmpty else { return [] }
        var checks: [Check] = []

        // Valuation — trailing P/E
        if let pe = f.trailingPE {
            let v: Verdict = pe <= 0 ? .weak : (pe < 20 ? .good : (pe < 35 ? .fair : .weak))
            let note = pe <= 0 ? "No positive trailing earnings." :
                "Each $1 of annual earnings costs about $\(String(format: "%.0f", pe)). Compare with sector peers."
            checks.append(Check(title: "Valuation (P/E)", verdict: v, detail: note))
        }

        // Growth bias — PEG
        if let peg = f.pegRatio, peg > 0 {
            let v: Verdict = peg < 1 ? .good : (peg < 2 ? .fair : .weak)
            checks.append(Check(title: "Growth-adjusted value (PEG)",
                                verdict: v,
                                detail: "PEG \(String(format: "%.2f", peg)). Under ~1 suggests growth may not be fully priced in."))
        }

        // Profitability — net margin
        if let m = f.profitMargin {
            let v: Verdict = m <= 0 ? .weak : (m < 0.08 ? .fair : .good)
            checks.append(Check(title: "Profitability (net margin)",
                                verdict: v,
                                detail: "Keeps \(Fmt.percentFromFraction(m)) of revenue as profit."))
        }

        // Return on equity
        if let roe = f.returnOnEquity {
            let v: Verdict = roe <= 0 ? .weak : (roe < 0.10 ? .fair : .good)
            checks.append(Check(title: "Return on equity",
                                verdict: v,
                                detail: "Generates \(Fmt.percentFromFraction(roe)) on shareholder capital."))
        }

        // Balance-sheet strength — debt/equity
        if let de = f.debtToEquity {
            // Yahoo reports this as a percentage (e.g. 55 == 0.55x).
            let ratio = de > 5 ? de / 100 : de
            let v: Verdict = ratio < 1 ? .good : (ratio < 2 ? .fair : .weak)
            checks.append(Check(title: "Balance sheet (debt/equity)",
                                verdict: v,
                                detail: "Debt is about \(String(format: "%.2f", ratio))× equity. Lower is safer; capital-heavy sectors run higher."))
        }

        // Revenue growth
        if let g = f.revenueGrowth {
            let v: Verdict = g < 0 ? .weak : (g < 0.05 ? .fair : .good)
            checks.append(Check(title: "Revenue growth (YoY)",
                                verdict: v,
                                detail: "Sales \(g < 0 ? "shrank" : "grew") \(Fmt.percentFromFraction(abs(g))) year over year."))
        }

        // Income — dividend yield (informational, not good/bad on its own)
        if let dy = f.dividendYield, dy > 0 {
            checks.append(Check(title: "Dividend yield",
                                verdict: .good,
                                detail: "Pays \(Fmt.percentFromFraction(dy)) annually. Check the payout ratio is sustainable."))
        }

        // Short interest — crowd betting against the stock (higher = riskier)
        if let sp = f.shortPercentOfFloat {
            let v: Verdict = sp < 0.03 ? .good : (sp < 0.08 ? .fair : .weak)
            var note = "\(Fmt.percentFromFraction(sp)) of float sold short."
            if let sr = f.shortRatio { note += " ~\(Fmt.number(sr, decimals: 1)) days to cover." }
            if sp >= 0.08 { note += " Heavily shorted — risk, but also squeeze fuel." }
            checks.append(Check(title: "Short interest", verdict: v, detail: note))
        }

        // Insider activity — insiders buying their own stock is a trusted signal
        if let net = f.insiderNetShares, net != 0 {
            let buying = net > 0
            let v: Verdict = buying ? .good : .weak
            let note = buying
                ? "Insiders were net buyers recently — often a confidence signal."
                : "Insiders were net sellers recently (note: selling has many benign reasons)."
            checks.append(Check(title: "Insider activity", verdict: v, detail: note))
        }

        // Volatility — beta
        if let beta = f.beta {
            let v: Verdict = beta < 1.2 ? .good : (beta < 1.6 ? .fair : .weak)
            checks.append(Check(title: "Volatility (beta)",
                                verdict: v,
                                detail: "Moves about \(String(format: "%.2f", beta))× the market. Above 1 is more volatile than the index."))
        }

        return checks
    }

    /// A compact 0–100 "fundamental health" score derived from the checks, for
    /// a quick glance. Returns nil when there's nothing to score.
    public static func healthScore(_ f: Fundamentals) -> Int? {
        let checks = evaluate(f).filter { $0.verdict != .unknown }
        guard !checks.isEmpty else { return nil }
        let points = checks.reduce(0.0) { acc, c in
            switch c.verdict {
            case .good: return acc + 1.0
            case .fair: return acc + 0.5
            case .weak, .unknown: return acc
            }
        }
        return Int((points / Double(checks.count) * 100).rounded())
    }
}
