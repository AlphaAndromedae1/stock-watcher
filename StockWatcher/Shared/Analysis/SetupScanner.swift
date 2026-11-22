import Foundation

/// Classic chart setups, as informational tags. Standard definitions.
public enum Setup: String, Sendable, CaseIterable {
    case breakout20 = "20-day breakout"
    case bullFlag = "Bull flag"
    case reclaimMA20 = "MA-20 reclaim"
    case oversoldBounce = "Oversold bounce"
}

public enum SetupScanner {
    public static func detect(_ candles: [Candle]) -> [Setup] {
        let c = candles.closes
        guard c.count >= 30 else { return [] }
        let n = c.count
        let last = c[n - 1]
        let prior = c[n - 2]
        guard prior > 0, c[n - 16] > 0 else { return [] }

        let hi20 = c[(n - 21)..<(n - 1)].max() ?? last
        let ma20 = c[(n - 20)...].reduce(0, +) / 20.0
        let ma20prev = c[(n - 21)..<(n - 1)].reduce(0, +) / 20.0
        let run = c[n - 6] / c[n - 16] - 1
        let window5 = c[(n - 5)...]
        let rng5 = ((window5.max() ?? last) - (window5.min() ?? last)) / last

        var out: [Setup] = []
        if last > hi20 { out.append(.breakout20) }
        if run > 0.10 && rng5 < 0.05 { out.append(.bullFlag) }
        if prior < ma20prev && last > ma20 { out.append(.reclaimMA20) }
        if let rp = Indicators.lastFinite(Indicators.rsi(Array(c.dropLast()), 14)),
           rp < 30, last > prior {
            out.append(.oversoldBounce)
        }
        return out
    }
}
