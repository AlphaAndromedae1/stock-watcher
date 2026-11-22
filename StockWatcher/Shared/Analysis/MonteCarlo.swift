import Foundation

/// Reproducible seeded PRNG (SplitMix64) so a given seed gives the same paths.
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func index(_ count: Int) -> Int {
        Int(next() % UInt64(max(count, 1)))
    }
}

public struct MonteCarloResult: Sendable, Equatable {
    public let horizonDays: Int
    public let startPrice: Double
    public let p5: Double
    public let p25: Double
    public let p50: Double
    public let p75: Double
    public let p95: Double
    public let probUp: Double           // fraction of paths ending above start
    public let meanEnd: Double
    public let bands: [[Double]]         // per-step [p10, p50, p90] for the fan
    public let probTarget: Double?       // if a target was supplied
    public let probStop: Double?         // if a stop was supplied
}

/// Bootstrap Monte Carlo: resamples the stock's own daily return factors to
/// simulate many possible future paths. A reality check on the range of
/// outcomes — NOT a prediction (it can't foresee earnings, gaps, news).
/// Adapted (re-implemented in Swift) from the MIT day-trader-skill Time Machine.
public enum MonteCarlo {
    public static func simulate(candles: [Candle],
                                horizonDays: Int,
                                replays: Int = 2500,
                                seed: UInt64 = 19,
                                target: Double? = nil,
                                stop: Double? = nil) -> MonteCarloResult? {
        let closes = candles.closes
        guard closes.count > 30, horizonDays > 0, let start = closes.last, start > 0 else { return nil }

        // Daily multiplicative return factors (close / previous close).
        var factors: [Double] = []
        factors.reserveCapacity(closes.count)
        for i in 1..<closes.count where closes[i - 1] > 0 {
            factors.append(closes[i] / closes[i - 1])
        }
        guard factors.count > 20 else { return nil }

        var rng = SplitMix64(seed: seed)
        var ends: [Double] = []
        ends.reserveCapacity(replays)

        let bandPathCount = min(replays, 800)
        var bandPaths: [[Double]] = []
        bandPaths.reserveCapacity(bandPathCount)

        var upCount = 0
        var targetCount = 0
        var stopCount = 0

        for n in 0..<replays {
            var price = start
            let keep = n < bandPathCount
            var path: [Double] = keep ? [price] : []
            var hitTarget = false
            var hitStop = false
            for _ in 0..<horizonDays {
                price *= factors[rng.index(factors.count)]
                if let t = target, price >= t { hitTarget = true }
                if let s = stop, price <= s { hitStop = true }
                if keep { path.append(price) }
            }
            ends.append(price)
            if price > start { upCount += 1 }
            if hitTarget { targetCount += 1 }
            if hitStop { stopCount += 1 }
            if keep { bandPaths.append(path) }
        }

        let sortedEnds = ends.sorted()
        func pctl(_ a: [Double], _ q: Double) -> Double {
            guard !a.isEmpty else { return 0 }
            let idx = min(a.count - 1, max(0, Int(q * Double(a.count))))
            return a[idx]
        }

        var bands: [[Double]] = []
        bands.reserveCapacity(horizonDays + 1)
        for step in 0...horizonDays {
            var column: [Double] = []
            column.reserveCapacity(bandPaths.count)
            for p in bandPaths where step < p.count { column.append(p[step]) }
            column.sort()
            bands.append([pctl(column, 0.10), pctl(column, 0.50), pctl(column, 0.90)])
        }

        let mean = ends.reduce(0, +) / Double(ends.count)
        let total = Double(replays)
        return MonteCarloResult(
            horizonDays: horizonDays,
            startPrice: start,
            p5: pctl(sortedEnds, 0.05),
            p25: pctl(sortedEnds, 0.25),
            p50: pctl(sortedEnds, 0.50),
            p75: pctl(sortedEnds, 0.75),
            p95: pctl(sortedEnds, 0.95),
            probUp: Double(upCount) / total,
            meanEnd: mean,
            bands: bands,
            probTarget: target != nil ? Double(targetCount) / total : nil,
            probStop: stop != nil ? Double(stopCount) / total : nil)
    }
}
