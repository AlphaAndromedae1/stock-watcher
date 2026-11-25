import SwiftUI
import Charts

/// Percentile "fan" of simulated price paths: the 10–90% band, the median line,
/// today's price, and optional target/stop lines.
struct FanChartView: View {
    let result: MonteCarloResult
    var target: Double?
    var stop: Double?

    private var steps: [(offset: Int, band: [Double])] {
        result.bands.enumerated().map { (offset: $0.offset, band: $0.element) }
    }

    var body: some View {
        Chart {
            ForEach(steps, id: \.offset) { item in
                AreaMark(
                    x: .value("Day", item.offset),
                    yStart: .value("Low", item.band[0]),
                    yEnd: .value("High", item.band[2])
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.accentColor.opacity(0.16))
            }
            ForEach(steps, id: \.offset) { item in
                LineMark(
                    x: .value("Day", item.offset),
                    y: .value("Median", item.band[1])
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.accentColor)
            }
            RuleMark(y: .value("Now", result.startPrice))
                .foregroundStyle(.secondary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4]))
            if let target {
                RuleMark(y: .value("Target", target))
                    .foregroundStyle(Pantone.emerald.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3]))
            }
            if let stop {
                RuleMark(y: .value("Stop", stop))
                    .foregroundStyle(Pantone.livingCoral.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3]))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(Fmt.number(v, decimals: v > 100 ? 0 : 1)).font(.caption2)
                    }
                }
            }
        }
        .frame(height: 150)
    }
}
