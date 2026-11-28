import Foundation

/// Objective, rule-based chart readings derived only from price and volume —
/// deliberately **not** subjective pattern-matching (no head-and-shoulders,
/// cup-and-handle, etc., which are noisy and weakly predictive). Informational
/// only: these never feed the Stock Watcher Score.
public struct ChartSignal: Equatable, Sendable, Identifiable {
    public enum Bias: String, Sendable { case bullish, bearish, neutral }

    public let title: String
    public let detail: String
    public let bias: Bias
    public let systemImage: String
    public var id: String { title }

    public init(title: String, detail: String, bias: Bias, systemImage: String) {
        self.title = title
        self.detail = detail
        self.bias = bias
        self.systemImage = systemImage
    }
}

public enum ChartSignalScanner {
    /// Scan ~1 year of daily candles for objective signals, most-notable first.
    public static func scan(_ candles: [Candle]) -> [ChartSignal] {
        guard candles.count >= 30 else { return [] }
        let closes = candles.map(\.close)
        let highs = candles.map(\.high)
        let lows = candles.map(\.low)
        let volumes = candles.map(\.volume)
        let lastClose = closes[closes.count - 1]

        var out: [ChartSignal] = []
        if let s = maCross(closes) { out.append(s) }
        if let s = range52(candles, lastClose: lastClose) { out.append(s) }

        let pivots = findPivots(highs: highs, lows: lows, k: 5)
        if let s = trendStructure(pivots) { out.append(s) }
        if let s = supportResistance(pivots, price: lastClose) { out.append(s) }

        if let s = volumeSpike(closes: closes, volumes: volumes) { out.append(s) }
        if let s = gapSignal(candles) { out.append(s) }
        return out
    }

    // MARK: 50/200-day moving-average cross

    private static func maCross(_ closes: [Double]) -> ChartSignal? {
        guard closes.count >= 200 else { return nil }
        let s50 = Indicators.sma(closes, 50)
        let s200 = Indicators.sma(closes, 200)
        let n = closes.count

        var lastCrossAgo: Int?
        var crossedUp = false
        var prevSign = 0
        for i in 0..<n {
            guard s50[i].isFinite, s200[i].isFinite else { continue }
            let sign = s50[i] > s200[i] ? 1 : (s50[i] < s200[i] ? -1 : 0)
            if prevSign != 0, sign != 0, sign != prevSign {
                lastCrossAgo = n - 1 - i
                crossedUp = sign > 0
            }
            if sign != 0 { prevSign = sign }
        }

        if let ago = lastCrossAgo, ago <= 30 {
            let when = ago == 0 ? "today" : "~\(ago) trading day\(ago == 1 ? "" : "s") ago"
            return ChartSignal(
                title: crossedUp ? "Golden cross" : "Death cross",
                detail: "The 50-day average crossed \(crossedUp ? "above" : "below") the 200-day \(when) — a slow but widely-watched long-term momentum shift.",
                bias: crossedUp ? .bullish : .bearish,
                systemImage: crossedUp ? "arrow.up.right.circle" : "arrow.down.right.circle")
        }

        let above = (Indicators.lastFinite(s50) ?? 0) >= (Indicators.lastFinite(s200) ?? 0)
        return ChartSignal(
            title: above ? "Above the 200-day average" : "Below the 200-day average",
            detail: "The 50-day average is \(above ? "above" : "below") the 200-day — the long-term trend is \(above ? "up" : "down").",
            bias: above ? .bullish : .bearish,
            systemImage: "chart.xyaxis.line")
    }

    // MARK: 52-week range position

    private static func range52(_ candles: [Candle], lastClose: Double) -> ChartSignal? {
        let window = candles.suffix(252)
        guard let hi = window.map(\.high).max(), let lo = window.map(\.low).min(), hi > lo else { return nil }
        let pos = (lastClose - lo) / (hi - lo) * 100
        let toHigh = (hi - lastClose) / hi * 100
        let toLow = (lastClose - lo) / lo * 100

        if lastClose >= hi * 0.999 {
            return ChartSignal(title: "New 52-week high",
                detail: "Trading at the top of its 52-week range — strong momentum, but watch for a stretched price.",
                bias: .bullish, systemImage: "arrow.up.to.line.compact")
        }
        if lastClose <= lo * 1.001 {
            return ChartSignal(title: "New 52-week low",
                detail: "Trading at the bottom of its 52-week range — weak momentum; confirm the business case before bottom-fishing.",
                bias: .bearish, systemImage: "arrow.down.to.line.compact")
        }
        if toHigh <= 3 {
            return ChartSignal(title: "Near 52-week high",
                detail: String(format: "About %.1f%% below its 52-week high (at %.0f%% of the yearly range).", toHigh, pos),
                bias: .bullish, systemImage: "arrow.up.to.line.compact")
        }
        if toLow <= 3 {
            return ChartSignal(title: "Near 52-week low",
                detail: String(format: "About %.1f%% above its 52-week low (at %.0f%% of the yearly range).", toLow, pos),
                bias: .bearish, systemImage: "arrow.down.to.line.compact")
        }
        return ChartSignal(title: "Mid 52-week range",
            detail: String(format: "Trading at %.0f%% of its 52-week range (low to high).", pos),
            bias: .neutral, systemImage: "arrow.up.and.down")
    }

    // MARK: Swing pivots (shared by trend + support/resistance)

    private struct Pivots {
        let highs: [(idx: Int, price: Double)]
        let lows: [(idx: Int, price: Double)]
    }

    private static func findPivots(highs: [Double], lows: [Double], k: Int) -> Pivots {
        var sh: [(Int, Double)] = []
        var sl: [(Int, Double)] = []
        let n = highs.count
        guard n > 2 * k else { return Pivots(highs: [], lows: []) }
        for i in k..<(n - k) {
            if let mx = highs[(i - k)...(i + k)].max(), highs[i] == mx { sh.append((i, highs[i])) }
            if let mn = lows[(i - k)...(i + k)].min(), lows[i] == mn { sl.append((i, lows[i])) }
        }
        return Pivots(highs: sh, lows: sl)
    }

    private static func trendStructure(_ p: Pivots) -> ChartSignal? {
        guard p.highs.count >= 2, p.lows.count >= 2 else { return nil }
        let h1 = p.highs[p.highs.count - 2].price, h2 = p.highs[p.highs.count - 1].price
        let l1 = p.lows[p.lows.count - 2].price, l2 = p.lows[p.lows.count - 1].price
        if h2 > h1, l2 > l1 {
            return ChartSignal(title: "Uptrend structure",
                detail: "Making higher highs and higher lows — a textbook uptrend.",
                bias: .bullish, systemImage: "chart.line.uptrend.xyaxis")
        }
        if h2 < h1, l2 < l1 {
            return ChartSignal(title: "Downtrend structure",
                detail: "Making lower highs and lower lows — a textbook downtrend.",
                bias: .bearish, systemImage: "chart.line.downtrend.xyaxis")
        }
        return ChartSignal(title: "Sideways / mixed",
            detail: "Highs and lows aren't trending cleanly — the stock is ranging or in transition.",
            bias: .neutral, systemImage: "arrow.left.and.right")
    }

    private static func supportResistance(_ p: Pivots, price: Double) -> ChartSignal? {
        guard price > 0 else { return nil }
        let support = p.lows.map(\.price).filter { $0 < price }.max()
        let resistance = p.highs.map(\.price).filter { $0 > price }.min()
        guard support != nil || resistance != nil else { return nil }

        var parts: [String] = []
        if let s = support {
            parts.append("support ~\(Fmt.number(s)) (\(String(format: "%.1f", (price - s) / price * 100))% below)")
        }
        if let r = resistance {
            parts.append("resistance ~\(Fmt.number(r)) (\(String(format: "%.1f", (r - price) / price * 100))% above)")
        }
        return ChartSignal(title: "Support & resistance",
            detail: "Recent swing levels: " + parts.joined(separator: ", ") + ".",
            bias: .neutral, systemImage: "ruler")
    }

    // MARK: Volume & gaps

    private static func volumeSpike(closes: [Double], volumes: [Double]) -> ChartSignal? {
        guard closes.count >= 2,
              let rv = Indicators.relativeVolume(volumes, period: 20), rv >= 1.8 else { return nil }
        let up = closes[closes.count - 1] >= closes[closes.count - 2]
        return ChartSignal(title: "Volume spike",
            detail: "Latest volume is about \(String(format: "%.1f", rv))× its 20-day average on \(up ? "an up" : "a down") day — unusual activity worth a look.",
            bias: up ? .bullish : .bearish, systemImage: "waveform.path.ecg")
    }

    private static func gapSignal(_ candles: [Candle]) -> ChartSignal? {
        guard candles.count >= 2 else { return nil }
        let prevClose = candles[candles.count - 2].close
        let open = candles[candles.count - 1].open
        guard prevClose > 0 else { return nil }
        let gap = (open - prevClose) / prevClose
        guard abs(gap) >= 0.03 else { return nil }
        let up = gap > 0
        return ChartSignal(title: up ? "Gap up" : "Gap down",
            detail: "Opened \(String(format: "%.1f", abs(gap) * 100))% \(up ? "above" : "below") the prior close — gaps often mark a news-driven move.",
            bias: up ? .bullish : .bearish, systemImage: up ? "arrow.up.forward" : "arrow.down.forward")
    }
}
