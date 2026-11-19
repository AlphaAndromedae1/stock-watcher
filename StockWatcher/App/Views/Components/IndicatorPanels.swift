import SwiftUI
import Charts

/// Candlestick chart drawn with paired RuleMarks (thin wick + thick body).
struct CandleChartView: View {
    let candles: [Candle]

    /// Cap bars so candles stay readable on phone widths.
    private var shown: [Candle] { Array(candles.suffix(90)) }

    private var yDomain: ClosedRange<Double> {
        let lows = shown.map(\.low), highs = shown.map(\.high)
        guard let lo = lows.min(), let hi = highs.max(), hi > lo else { return 0...1 }
        let pad = (hi - lo) * 0.06
        return (lo - pad)...(hi + pad)
    }

    private var bodyWidth: Double {
        let n = max(shown.count, 1)
        return max(1.5, min(6, 320.0 / Double(n)))
    }

    private func color(_ c: Candle) -> Color { Color.forChange(c.close >= c.open) }

    var body: some View {
        Chart(shown) { c in
            RuleMark(x: .value("Date", c.date),
                     yStart: .value("Low", c.low),
                     yEnd: .value("High", c.high))
                .foregroundStyle(color(c))
                .lineStyle(StrokeStyle(lineWidth: 1))

            RuleMark(x: .value("Date", c.date),
                     yStart: .value("Open", c.open),
                     yEnd: .value("Close", c.close))
                .foregroundStyle(color(c))
                .lineStyle(StrokeStyle(lineWidth: bodyWidth, lineCap: .round))
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(Fmt.number(v, decimals: v > 100 ? 0 : 2)).font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 200)
    }
}

/// RSI(14) subpanel with 30/70 guide lines.
struct RSIChartView: View {
    let candles: [Candle]

    private var points: [(date: Date, value: Double)] {
        let rsi = Indicators.rsi(candles.closes, 14)
        return zip(candles, rsi).compactMap { c, r in r.isFinite ? (c.date, r) : nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("RSI (14)").font(.caption2).foregroundStyle(.secondary)
            Chart {
                ForEach(points, id: \.date) { p in
                    LineMark(x: .value("Date", p.date), y: .value("RSI", p.value))
                        .foregroundStyle(.purple)
                }
                RuleMark(y: .value("Overbought", 70))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4]))
                RuleMark(y: .value("Oversold", 30))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4]))
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .trailing, values: [30, 70]) {
                    AxisValueLabel()
                }
            }
            .chartXAxis(.hidden)
            .frame(height: 70)
        }
    }
}

/// Volume subpanel: bars colored by up/down day, with relative-volume label.
struct VolumeChartView: View {
    let candles: [Candle]

    private var relVol: Double? { Indicators.relativeVolume(candles.volumes) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Volume").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if let r = relVol {
                    Text(String(format: "%.1f× avg", r))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(r >= 1.5 ? Color.forChange(true) : .secondary)
                }
            }
            Chart(candles) { c in
                BarMark(x: .value("Date", c.date), y: .value("Volume", c.volume))
                    .foregroundStyle(Color.forChange(c.close >= c.open).opacity(0.45))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 44)
        }
    }
}

/// MACD(12,26,9) subpanel: histogram + MACD and signal lines.
struct MACDChartView: View {
    let candles: [Candle]

    var body: some View {
        let m = Indicators.macd(candles.closes)
        let hist = zip(candles, m.histogram).compactMap { c, v in v.isFinite ? (c.date, v) : nil }
        let macd = zip(candles, m.macd).compactMap { c, v in v.isFinite ? (c.date, v) : nil }
        let signal = zip(candles, m.signal).compactMap { c, v in v.isFinite ? (c.date, v) : nil }

        return VStack(alignment: .leading, spacing: 2) {
            Text("MACD (12,26,9)").font(.caption2).foregroundStyle(.secondary)
            Chart {
                ForEach(hist, id: \.0) { p in
                    BarMark(x: .value("Date", p.0), y: .value("Hist", p.1))
                        .foregroundStyle(Color.forChange(p.1 >= 0).opacity(0.5))
                }
                ForEach(macd, id: \.0) { p in
                    LineMark(x: .value("Date", p.0), y: .value("MACD", p.1))
                        .foregroundStyle(.blue)
                }
                ForEach(signal, id: \.0) { p in
                    LineMark(x: .value("Date", p.0), y: .value("Signal", p.1))
                        .foregroundStyle(.orange)
                }
            }
            .chartXAxis(.hidden)
            .frame(height: 80)
        }
    }
}
