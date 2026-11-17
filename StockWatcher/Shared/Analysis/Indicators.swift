import Foundation

/// Pure, dependency-free technical-indicator math.
///
/// Every function returns a full-length array aligned to the input, with
/// `Double.nan` filling the warm-up region before the indicator is defined.
/// Finite values are always contiguous at the tail, so `lastTwoFinite` reads
/// the latest reading and the one before it in the correct order.
public enum Indicators {

    // MARK: - Reading helpers

    public static func lastFinite(_ a: [Double]) -> Double? {
        a.last(where: { $0.isFinite })
    }

    /// Returns (previous, current) from the finite tail, or nil if <2 exist.
    public static func lastTwoFinite(_ a: [Double]) -> (prev: Double, curr: Double)? {
        let f = a.filter { $0.isFinite }
        guard f.count >= 2 else { return nil }
        return (f[f.count - 2], f[f.count - 1])
    }

    // MARK: - Moving averages

    public static func sma(_ src: [Double], _ period: Int) -> [Double] {
        var out = Array(repeating: Double.nan, count: src.count)
        guard period > 0, src.count >= period else { return out }
        var sum = 0.0
        for i in src.indices {
            sum += src[i]
            if i >= period { sum -= src[i - period] }
            if i >= period - 1 { out[i] = sum / Double(period) }
        }
        return out
    }

    /// EMA tolerant of leading NaNs (so it can smooth MACD etc.).
    public static func ema(_ src: [Double], _ period: Int) -> [Double] {
        var out = Array(repeating: Double.nan, count: src.count)
        guard period > 0, let start = src.firstIndex(where: { $0.isFinite }) else { return out }
        guard src.count - start >= period else { return out }
        let k = 2.0 / Double(period + 1)
        var prev = 0.0
        for j in 0..<period { prev += src[start + j] }
        prev /= Double(period)
        out[start + period - 1] = prev
        for i in (start + period)..<src.count {
            let v = src[i]
            guard v.isFinite else { out[i] = prev; continue }
            prev = (v - prev) * k + prev
            out[i] = prev
        }
        return out
    }

    public static func wma(_ src: [Double], _ period: Int) -> [Double] {
        var out = Array(repeating: Double.nan, count: src.count)
        guard period > 0, src.count >= period else { return out }
        let denom = Double(period * (period + 1) / 2)
        for i in (period - 1)..<src.count {
            var sum = 0.0
            var ok = true
            for j in 0..<period {
                let v = src[i - j]
                if !v.isFinite { ok = false; break }
                sum += v * Double(period - j)
            }
            out[i] = ok ? sum / denom : .nan
        }
        return out
    }

    public static func hma(_ src: [Double], _ period: Int) -> [Double] {
        guard period > 1 else { return src }
        let half = max(1, period / 2)
        let sqrtP = max(1, Int(Double(period).squareRoot().rounded()))
        let wHalf = wma(src, half)
        let wFull = wma(src, period)
        let raw = zip(wHalf, wFull).map { a, b in
            (a.isFinite && b.isFinite) ? 2 * a - b : Double.nan
        }
        return wma(raw, sqrtP)
    }

    public static func vwma(_ closes: [Double], _ volumes: [Double], _ period: Int) -> [Double] {
        var out = Array(repeating: Double.nan, count: closes.count)
        guard period > 0, closes.count >= period, volumes.count == closes.count else { return out }
        for i in (period - 1)..<closes.count {
            var pv = 0.0, v = 0.0
            for j in 0..<period {
                pv += closes[i - j] * volumes[i - j]
                v += volumes[i - j]
            }
            out[i] = v > 0 ? pv / v : .nan
        }
        return out
    }

    // MARK: - Oscillators

    public static func rsi(_ src: [Double], _ period: Int = 14) -> [Double] {
        var out = Array(repeating: Double.nan, count: src.count)
        guard src.count > period else { return out }
        var gain = 0.0, loss = 0.0
        for i in 1...period {
            let ch = src[i] - src[i - 1]
            if ch >= 0 { gain += ch } else { loss -= ch }
        }
        var avgGain = gain / Double(period)
        var avgLoss = loss / Double(period)
        out[period] = rsiValue(avgGain, avgLoss)
        guard src.count > period + 1 else { return out }
        for i in (period + 1)..<src.count {
            let ch = src[i] - src[i - 1]
            let g = ch > 0 ? ch : 0
            let l = ch < 0 ? -ch : 0
            avgGain = (avgGain * Double(period - 1) + g) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + l) / Double(period)
            out[i] = rsiValue(avgGain, avgLoss)
        }
        return out
    }

    private static func rsiValue(_ g: Double, _ l: Double) -> Double {
        l == 0 ? 100 : 100 - 100 / (1 + g / l)
    }

    public struct MACDResult { public let macd: [Double]; public let signal: [Double]; public let histogram: [Double] }

    public static func macd(_ src: [Double], fast: Int = 12, slow: Int = 26, signalPeriod: Int = 9) -> MACDResult {
        let emaFast = ema(src, fast)
        let emaSlow = ema(src, slow)
        let line = zip(emaFast, emaSlow).map { a, b in
            (a.isFinite && b.isFinite) ? a - b : Double.nan
        }
        let sig = ema(line, signalPeriod)
        let hist = zip(line, sig).map { a, b in
            (a.isFinite && b.isFinite) ? a - b : Double.nan
        }
        return MACDResult(macd: line, signal: sig, histogram: hist)
    }

    public struct Stochastic { public let k: [Double]; public let d: [Double] }

    public static func stochastic(high: [Double], low: [Double], close: [Double],
                                  period: Int = 14, smoothK: Int = 3, smoothD: Int = 3) -> Stochastic {
        let n = close.count
        var raw = Array(repeating: Double.nan, count: n)
        guard n >= period else { return Stochastic(k: raw, d: raw) }
        for i in (period - 1)..<n {
            let hh = high[(i - period + 1)...i].max() ?? high[i]
            let ll = low[(i - period + 1)...i].min() ?? low[i]
            raw[i] = hh - ll == 0 ? 50 : (close[i] - ll) / (hh - ll) * 100
        }
        let k = sma(raw, smoothK)
        let d = sma(k, smoothD)
        return Stochastic(k: k, d: d)
    }

    public static func cci(high: [Double], low: [Double], close: [Double], period: Int = 20) -> [Double] {
        let n = close.count
        var out = Array(repeating: Double.nan, count: n)
        guard n >= period else { return out }
        let tp = (0..<n).map { (high[$0] + low[$0] + close[$0]) / 3 }
        let smatp = sma(tp, period)
        for i in (period - 1)..<n {
            guard smatp[i].isFinite else { continue }
            var dev = 0.0
            for j in 0..<period { dev += abs(tp[i - j] - smatp[i]) }
            let meanDev = dev / Double(period)
            out[i] = meanDev == 0 ? 0 : (tp[i] - smatp[i]) / (0.015 * meanDev)
        }
        return out
    }

    public struct DMI { public let plusDI: [Double]; public let minusDI: [Double]; public let adx: [Double] }

    public static func dmi(high: [Double], low: [Double], close: [Double], period: Int = 14) -> DMI {
        let n = close.count
        let nan = Array(repeating: Double.nan, count: n)
        guard n > period * 2 else { return DMI(plusDI: nan, minusDI: nan, adx: nan) }

        var tr = Array(repeating: 0.0, count: n)
        var plusDM = Array(repeating: 0.0, count: n)
        var minusDM = Array(repeating: 0.0, count: n)
        for i in 1..<n {
            let upMove = high[i] - high[i - 1]
            let downMove = low[i - 1] - low[i]
            plusDM[i] = (upMove > downMove && upMove > 0) ? upMove : 0
            minusDM[i] = (downMove > upMove && downMove > 0) ? downMove : 0
            let hl = high[i] - low[i]
            let hc = abs(high[i] - close[i - 1])
            let lc = abs(low[i] - close[i - 1])
            tr[i] = max(hl, hc, lc)
        }

        // Wilder smoothing
        var smTR = 0.0, smPlus = 0.0, smMinus = 0.0
        for i in 1...period { smTR += tr[i]; smPlus += plusDM[i]; smMinus += minusDM[i] }

        var plusDI = Array(repeating: Double.nan, count: n)
        var minusDI = Array(repeating: Double.nan, count: n)
        var dx = Array(repeating: Double.nan, count: n)

        func fill(_ i: Int) {
            let pdi = smTR == 0 ? 0 : 100 * smPlus / smTR
            let mdi = smTR == 0 ? 0 : 100 * smMinus / smTR
            plusDI[i] = pdi
            minusDI[i] = mdi
            let sum = pdi + mdi
            dx[i] = sum == 0 ? 0 : 100 * abs(pdi - mdi) / sum
        }
        fill(period)
        for i in (period + 1)..<n {
            smTR = smTR - smTR / Double(period) + tr[i]
            smPlus = smPlus - smPlus / Double(period) + plusDM[i]
            smMinus = smMinus - smMinus / Double(period) + minusDM[i]
            fill(i)
        }

        // ADX = Wilder-smoothed DX
        var adx = Array(repeating: Double.nan, count: n)
        let firstDX = period
        let adxStart = firstDX + period - 1
        if adxStart < n {
            var sum = 0.0
            for i in firstDX..<(firstDX + period) { sum += dx[i] }
            var prev = sum / Double(period)
            adx[adxStart] = prev
            for i in (adxStart + 1)..<n {
                prev = (prev * Double(period - 1) + dx[i]) / Double(period)
                adx[i] = prev
            }
        }
        return DMI(plusDI: plusDI, minusDI: minusDI, adx: adx)
    }

    public static func awesomeOscillator(high: [Double], low: [Double]) -> [Double] {
        let median = zip(high, low).map { ($0 + $1) / 2 }
        let fast = sma(median, 5)
        let slow = sma(median, 34)
        return zip(fast, slow).map { a, b in (a.isFinite && b.isFinite) ? a - b : Double.nan }
    }

    public static func momentum(_ src: [Double], period: Int = 10) -> [Double] {
        var out = Array(repeating: Double.nan, count: src.count)
        guard src.count > period else { return out }
        for i in period..<src.count { out[i] = src[i] - src[i - period] }
        return out
    }

    public static func stochRSI(_ src: [Double], rsiPeriod: Int = 14, stochPeriod: Int = 14,
                                smoothK: Int = 3, smoothD: Int = 3) -> Stochastic {
        let r = rsi(src, rsiPeriod)
        let n = src.count
        var stoch = Array(repeating: Double.nan, count: n)
        for i in 0..<n {
            guard i >= stochPeriod - 1 else { continue }
            let window = r[(i - stochPeriod + 1)...i].filter { $0.isFinite }
            guard window.count == stochPeriod, let mn = window.min(), let mx = window.max() else { continue }
            stoch[i] = mx - mn == 0 ? 50 : (r[i] - mn) / (mx - mn) * 100
        }
        let k = sma(stoch, smoothK)
        let d = sma(k, smoothD)
        return Stochastic(k: k, d: d)
    }

    public static func williamsR(high: [Double], low: [Double], close: [Double], period: Int = 14) -> [Double] {
        let n = close.count
        var out = Array(repeating: Double.nan, count: n)
        guard n >= period else { return out }
        for i in (period - 1)..<n {
            let hh = high[(i - period + 1)...i].max() ?? high[i]
            let ll = low[(i - period + 1)...i].min() ?? low[i]
            out[i] = hh - ll == 0 ? -50 : (hh - close[i]) / (hh - ll) * -100
        }
        return out
    }

    public static func ultimateOscillator(high: [Double], low: [Double], close: [Double],
                                           short: Int = 7, medium: Int = 14, long: Int = 28) -> [Double] {
        let n = close.count
        var out = Array(repeating: Double.nan, count: n)
        guard n > long else { return out }
        var bp = Array(repeating: 0.0, count: n)
        var tr = Array(repeating: 0.0, count: n)
        for i in 1..<n {
            let minLC = min(low[i], close[i - 1])
            bp[i] = close[i] - minLC
            tr[i] = max(high[i], close[i - 1]) - minLC
        }
        func avg(_ i: Int, _ p: Int) -> Double {
            var sb = 0.0, st = 0.0
            for j in 0..<p { sb += bp[i - j]; st += tr[i - j] }
            return st == 0 ? 0 : sb / st
        }
        for i in long..<n {
            let a = avg(i, short), b = avg(i, medium), c = avg(i, long)
            out[i] = 100 * (4 * a + 2 * b + c) / 7
        }
        return out
    }

    public struct BullBear { public let bull: [Double]; public let bear: [Double]; public let ema: [Double] }

    public static func bullBearPower(high: [Double], low: [Double], close: [Double], period: Int = 13) -> BullBear {
        let e = ema(close, period)
        let bull = zip(high, e).map { h, m in m.isFinite ? h - m : Double.nan }
        let bear = zip(low, e).map { l, m in m.isFinite ? l - m : Double.nan }
        return BullBear(bull: bull, bear: bear, ema: e)
    }

    public struct Ichimoku {
        public let conversion: [Double]
        public let base: [Double]
        public let spanA: [Double]
        public let spanB: [Double]
    }

    public static func ichimoku(high: [Double], low: [Double],
                                conversionPeriod: Int = 9, basePeriod: Int = 26, spanBPeriod: Int = 52) -> Ichimoku {
        let n = high.count
        func midpoint(_ period: Int) -> [Double] {
            var out = Array(repeating: Double.nan, count: n)
            guard n >= period else { return out }
            for i in (period - 1)..<n {
                let hh = high[(i - period + 1)...i].max() ?? high[i]
                let ll = low[(i - period + 1)...i].min() ?? low[i]
                out[i] = (hh + ll) / 2
            }
            return out
        }
        let conv = midpoint(conversionPeriod)
        let base = midpoint(basePeriod)
        let spanA = zip(conv, base).map { a, b in (a.isFinite && b.isFinite) ? (a + b) / 2 : Double.nan }
        let spanB = midpoint(spanBPeriod)
        return Ichimoku(conversion: conv, base: base, spanA: spanA, spanB: spanB)
    }
}
