import SwiftUI
import Charts

struct PriceChartView: View {
    let candles: [Candle]

    private var trendUp: Bool {
        guard let first = candles.first?.close, let last = candles.last?.close else { return true }
        return last >= first
    }

    private var yDomain: ClosedRange<Double> {
        let lows = candles.map(\.low)
        let highs = candles.map(\.high)
        guard let lo = lows.min(), let hi = highs.max(), hi > lo else { return 0...1 }
        let pad = (hi - lo) * 0.06
        return (lo - pad)...(hi + pad)
    }

    var body: some View {
        let color = Color.forChange(trendUp)
        Chart(candles) { candle in
            AreaMark(
                x: .value("Date", candle.date),
                yStart: .value("Low", yDomain.lowerBound),
                yEnd: .value("Close", candle.close)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(
                LinearGradient(colors: [color.opacity(0.28), color.opacity(0.01)],
                               startPoint: .top, endPoint: .bottom)
            )

            LineMark(
                x: .value("Date", candle.date),
                y: .value("Close", candle.close)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(Fmt.number(v, decimals: v > 100 ? 0 : 2))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
            }
        }
        .frame(height: 200)
    }
}
