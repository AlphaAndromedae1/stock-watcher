import Foundation

/// Turns price history into a TradingView-style rating.
///
/// Each of 11 oscillators and up to 15 moving averages casts a Buy / Sell /
/// Neutral vote using TradingView's published methodology. Votes are averaged
/// (Buy = +1, Sell = -1, Neutral = 0) and bucketed into Strong Sell … Strong Buy.
/// The headline summary averages every indicator in both groups.
///
/// Ratings are computed on **daily** candles (feed it ~1 year of daily bars so
/// the 200-period moving averages are defined). Indicators that can't be
/// computed from the supplied history are skipped rather than counted neutral.
public enum TechnicalAnalyzer {

    public static func analyze(_ candles: [Candle]) -> TechnicalRating {
        let close = candles.closes
        let high = candles.highs
        let low = candles.lows
        let volume = candles.volumes
        let price = close.last ?? 0

        var oscillators: [IndicatorResult] = []
        var mas: [IndicatorResult] = []

        func add(_ list: inout [IndicatorResult], _ name: String, _ value: Double?, _ signal: Signal) {
            list.append(IndicatorResult(name: name, value: value, signal: signal))
        }

        // ---- Oscillators -----------------------------------------------------

        // RSI(14)
        let rsi = Indicators.rsi(close, 14)
        if let (prev, curr) = Indicators.lastTwoFinite(rsi) {
            let s: Signal = (curr < 30 && curr > prev) ? .buy
                          : (curr > 70 && curr < prev) ? .sell : .neutral
            add(&oscillators, "RSI (14)", curr, s)
        }

        // Stochastic %K (14,3,3)
        let stoch = Indicators.stochastic(high: high, low: low, close: close)
        if let p = crossPair(stoch.k, stoch.d) {
            let s: Signal = (p.aCurr < 20 && p.aCurr > p.bCurr && p.aPrev < p.bPrev) ? .buy
                          : (p.aCurr > 80 && p.aCurr < p.bCurr && p.aPrev > p.bPrev) ? .sell : .neutral
            add(&oscillators, "Stochastic %K (14,3,3)", p.aCurr, s)
        }

        // CCI(20)
        let cci = Indicators.cci(high: high, low: low, close: close, period: 20)
        if let (prev, curr) = Indicators.lastTwoFinite(cci) {
            let s: Signal = (curr < -100 && curr > prev) ? .buy
                          : (curr > 100 && curr < prev) ? .sell : .neutral
            add(&oscillators, "CCI (20)", curr, s)
        }

        // ADX(14)
        let dmi = Indicators.dmi(high: high, low: low, close: close, period: 14)
        if let adx = Indicators.lastFinite(dmi.adx),
           let di = crossPair(dmi.plusDI, dmi.minusDI) {
            let plusRising = di.aCurr > di.aPrev
            let s: Signal = (adx > 20 && di.aCurr > di.bCurr && plusRising) ? .buy
                          : (adx > 20 && di.aCurr < di.bCurr && !plusRising) ? .sell : .neutral
            add(&oscillators, "Average Directional Index (14)", adx, s)
        }

        // Awesome Oscillator
        let ao = Indicators.awesomeOscillator(high: high, low: low)
        if let (o2, o1, o0) = lastThreeFinite(ao) {
            let crossUp = o1 < 0 && o0 > 0
            let saucerUp = o0 > 0 && o2 > o1 && o1 < o0
            let crossDown = o1 > 0 && o0 < 0
            let saucerDown = o0 < 0 && o2 < o1 && o1 > o0
            let s: Signal = (crossUp || saucerUp) ? .buy : (crossDown || saucerDown) ? .sell : .neutral
            add(&oscillators, "Awesome Oscillator", o0, s)
        }

        // Momentum(10)
        let mom = Indicators.momentum(close, period: 10)
        if let (prev, curr) = Indicators.lastTwoFinite(mom) {
            let s: Signal = curr > prev ? .buy : curr < prev ? .sell : .neutral
            add(&oscillators, "Momentum (10)", curr, s)
        }

        // MACD (12,26,9)
        let macd = Indicators.macd(close)
        if let p = crossPair(macd.macd, macd.signal) {
            let s: Signal = p.aCurr > p.bCurr ? .buy : p.aCurr < p.bCurr ? .sell : .neutral
            add(&oscillators, "MACD (12,26,9)", p.aCurr, s)
        }

        // Stochastic RSI (fast)
        let srsi = Indicators.stochRSI(close)
        if let p = crossPair(srsi.k, srsi.d) {
            let s: Signal = (p.aCurr < 20 && p.aCurr > p.bCurr) ? .buy
                          : (p.aCurr > 80 && p.aCurr < p.bCurr) ? .sell : .neutral
            add(&oscillators, "Stochastic RSI Fast (3,3,14,14)", p.aCurr, s)
        }

        // Williams %R (14)
        let wr = Indicators.williamsR(high: high, low: low, close: close, period: 14)
        if let (prev, curr) = Indicators.lastTwoFinite(wr) {
            let s: Signal = (curr < -80 && curr > prev) ? .buy
                          : (curr > -20 && curr < prev) ? .sell : .neutral
            add(&oscillators, "Williams %R (14)", curr, s)
        }

        // Ultimate Oscillator (7,14,28)
        let uo = Indicators.ultimateOscillator(high: high, low: low, close: close)
        if let curr = Indicators.lastFinite(uo) {
            let s: Signal = curr > 70 ? .buy : curr < 30 ? .sell : .neutral
            add(&oscillators, "Ultimate Oscillator (7,14,28)", curr, s)
        }

        // Bull Bear Power (13)
        let bbp = Indicators.bullBearPower(high: high, low: low, close: close, period: 13)
        if let emaPair = Indicators.lastTwoFinite(bbp.ema),
           let bearPair = Indicators.lastTwoFinite(bbp.bear),
           let bullPair = Indicators.lastTwoFinite(bbp.bull) {
            let emaRising = emaPair.curr > emaPair.prev
            let buy = emaRising && bearPair.curr < 0 && bearPair.curr > bearPair.prev
            let sell = !emaRising && bullPair.curr > 0 && bullPair.curr < bullPair.prev
            let s: Signal = buy ? .buy : sell ? .sell : .neutral
            add(&oscillators, "Bull Bear Power (13)", bullPair.curr + bearPair.curr, s)
        }

        // Money Flow Index (14) — volume-weighted RSI (buying/selling pressure)
        let mfi = Indicators.moneyFlowIndex(high: high, low: low, close: close, volume: volume, period: 14)
        if let (prev, curr) = Indicators.lastTwoFinite(mfi) {
            let s: Signal = (curr < 20 && curr > prev) ? .buy
                          : (curr > 80 && curr < prev) ? .sell : .neutral
            add(&oscillators, "Money Flow Index (14)", curr, s)
        }

        // On-Balance Volume — accumulation vs distribution (OBV vs its EMA)
        let obv = Indicators.obv(close: close, volume: volume)
        let obvEMA = Indicators.ema(obv, 20)
        if let o = Indicators.lastFinite(obv), let e = Indicators.lastFinite(obvEMA) {
            let s: Signal = o > e ? .buy : o < e ? .sell : .neutral
            add(&oscillators, "On-Balance Volume", nil, s)
        }

        // ---- Moving averages -------------------------------------------------

        func maSignal(_ value: Double) -> Signal {
            price > value ? .buy : price < value ? .sell : .neutral
        }

        for p in [10, 20, 30, 50, 100, 200] {
            if let v = Indicators.lastFinite(Indicators.sma(close, p)) {
                add(&mas, "SMA (\(p))", v, maSignal(v))
            }
        }
        for p in [10, 20, 30, 50, 100, 200] {
            if let v = Indicators.lastFinite(Indicators.ema(close, p)) {
                add(&mas, "EMA (\(p))", v, maSignal(v))
            }
        }

        // Ichimoku Base Line (9,26,52,26)
        let ichi = Indicators.ichimoku(high: high, low: low)
        if let base = Indicators.lastFinite(ichi.base),
           let conv = Indicators.lastFinite(ichi.conversion),
           let spanA = Indicators.lastFinite(ichi.spanA),
           let spanB = Indicators.lastFinite(ichi.spanB) {
            let aboveCloud = price > max(spanA, spanB)
            let belowCloud = price < min(spanA, spanB)
            let s: Signal = (price > base && conv > base && aboveCloud) ? .buy
                          : (price < base && conv < base && belowCloud) ? .sell : .neutral
            add(&mas, "Ichimoku Base Line (9,26,52,26)", base, s)
        }

        // VWMA (20)
        if let v = Indicators.lastFinite(Indicators.vwma(close, volume, 20)) {
            add(&mas, "Volume Weighted MA (20)", v, maSignal(v))
        }

        // Hull MA (9)
        let hma = Indicators.hma(close, 9)
        if let (prev, curr) = Indicators.lastTwoFinite(hma) {
            let s: Signal = curr > prev ? .buy : curr < prev ? .sell : .neutral
            add(&mas, "Hull Moving Average (9)", curr, s)
        }

        // Money flow: accumulation vs distribution from OBV trend + MFI level.
        var flowScore = 0
        if let o = Indicators.lastFinite(obv), let e = Indicators.lastFinite(obvEMA) {
            flowScore += o > e ? 1 : (o < e ? -1 : 0)
        }
        if let m = Indicators.lastFinite(mfi) {
            flowScore += m > 55 ? 1 : (m < 45 ? -1 : 0)
        }
        let flow: Flow = flowScore > 0 ? .accumulating : (flowScore < 0 ? .distributing : .neutral)

        return TechnicalRating(
            oscillators: RatingGroup(title: "Oscillators", results: oscillators),
            movingAverages: RatingGroup(title: "Moving Averages", results: mas),
            flow: flow
        )
    }

    // MARK: - helpers

    private struct Pair { let aCurr: Double; let aPrev: Double; let bCurr: Double; let bPrev: Double }

    /// Current & previous values of two series at the latest shared finite bar.
    private static func crossPair(_ a: [Double], _ b: [Double]) -> Pair? {
        let n = Swift.min(a.count, b.count)
        guard n >= 2 else { return nil }
        let i = n - 1
        guard a[i].isFinite, b[i].isFinite, a[i - 1].isFinite, b[i - 1].isFinite else { return nil }
        return Pair(aCurr: a[i], aPrev: a[i - 1], bCurr: b[i], bPrev: b[i - 1])
    }

    private static func lastThreeFinite(_ a: [Double]) -> (Double, Double, Double)? {
        let f = a.filter { $0.isFinite }
        guard f.count >= 3 else { return nil }
        return (f[f.count - 3], f[f.count - 2], f[f.count - 1])
    }
}
