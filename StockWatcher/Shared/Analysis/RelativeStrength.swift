import Foundation

/// How a stock has performed against its market benchmark over several windows.
/// "Excess" return = stock return − index return; positive means the stock is
/// leading the market (relative strength). Informational only — not scored.
public struct RelativeStrength: Equatable, Sendable {
    public enum Verdict: String, Sendable {
        case leading, inLine, lagging

        public var title: String {
            switch self {
            case .leading: return "Leading"
            case .inLine:  return "In line"
            case .lagging: return "Lagging"
            }
        }
    }

    public struct Window: Equatable, Sendable, Identifiable {
        public let label: String         // "1M", "3M", "6M", "1Y"
        public let stockReturn: Double    // fraction, e.g. 0.12
        public let indexReturn: Double
        public var excess: Double { stockReturn - indexReturn }
        public var id: String { label }

        public init(label: String, stockReturn: Double, indexReturn: Double) {
            self.label = label
            self.stockReturn = stockReturn
            self.indexReturn = indexReturn
        }
    }

    public let benchmarkName: String
    public let windows: [Window]

    public init(benchmarkName: String, windows: [Window]) {
        self.benchmarkName = benchmarkName
        self.windows = windows
    }

    /// Overall read, anchored on the 3-month excess (falls back to the average
    /// of whatever windows are available).
    public var verdict: Verdict {
        let threeM = windows.first { $0.label == "3M" }?.excess
        let basis = threeM ?? (windows.isEmpty ? 0
            : windows.map(\.excess).reduce(0, +) / Double(windows.count))
        if basis > 0.02 { return .leading }
        if basis < -0.02 { return .lagging }
        return .inLine
    }
}

public enum RelativeStrengthAnalyzer {
    private static let windows: [(label: String, days: Int)] =
        [("1M", 21), ("3M", 63), ("6M", 126), ("1Y", 252)]

    /// Compares two daily close series by positional offset (both are daily
    /// bars from the same provider, so they line up closely enough for an
    /// informational read; minor holiday misalignment is tolerated).
    public static func compute(stock: [Candle], index: [Candle],
                               benchmarkName: String) -> RelativeStrength? {
        let s = stock.map(\.close)
        let i = index.map(\.close)
        guard s.count >= 22, i.count >= 22 else { return nil }

        var out: [RelativeStrength.Window] = []
        for w in windows {
            guard let sr = ret(s, w.days), let ir = ret(i, w.days) else { continue }
            out.append(RelativeStrength.Window(label: w.label, stockReturn: sr, indexReturn: ir))
        }
        guard !out.isEmpty else { return nil }
        return RelativeStrength(benchmarkName: benchmarkName, windows: out)
    }

    /// Return over the last `days` bars; clamps to the earliest bar when the
    /// series is a little shorter than the window (e.g. ~250 bars for "1Y").
    private static func ret(_ closes: [Double], _ days: Int) -> Double? {
        guard closes.count >= 2, let last = closes.last else { return nil }
        let idx = max(0, closes.count - 1 - days)
        let start = closes[idx]
        guard start.isFinite, start != 0, last.isFinite else { return nil }
        return (last - start) / start
    }
}
