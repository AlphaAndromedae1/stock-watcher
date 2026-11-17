import SwiftUI

/// A semicircular "speedometer" gauge: five colored zones from Strong Sell to
/// Strong Buy with a needle at the summary position.
struct RatingGaugeView: View {
    let average: Double          // -1 … 1
    let recommendation: Recommendation

    private var zoneColors: [Color] {
        [Recommendation.strongSell, .sell, .neutral, .buy, .strongBuy].map(\.color)
    }

    private var clampedAverage: Double {
        guard average.isFinite else { return 0 }
        return min(max(average, -1), 1)
    }

    var body: some View {
        VStack(spacing: 10) {
            Canvas { context, size in
                let availR = min(size.width / 2, size.height)
                let lineWidth = availR * 0.26
                let r = max(availR - lineWidth / 2 - 4, 1)
                let cx = size.width / 2
                let cy = size.height - 2

                // Zones (left -> right = Strong Sell -> Strong Buy).
                for i in 0..<5 {
                    var p = Path()
                    p.addArc(center: CGPoint(x: cx, y: cy),
                             radius: r,
                             startAngle: .degrees(180 + 36 * Double(i) + 1.2),
                             endAngle: .degrees(180 + 36 * Double(i + 1) - 1.2),
                             clockwise: false)
                    context.stroke(p, with: .color(zoneColors[i]),
                                   style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                }

                // Needle.
                let theta = (180 + (clampedAverage + 1) * 90) * .pi / 180
                let tip = CGPoint(x: cx + cos(theta) * (r - 2),
                                  y: cy + sin(theta) * (r - 2))
                var needle = Path()
                needle.move(to: CGPoint(x: cx, y: cy))
                needle.addLine(to: tip)
                context.stroke(needle, with: .color(.primary),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // Hub.
                let hub = Path(ellipseIn: CGRect(x: cx - 7, y: cy - 7, width: 14, height: 14))
                context.fill(hub, with: .color(.primary))
                let hub2 = Path(ellipseIn: CGRect(x: cx - 3.5, y: cy - 3.5, width: 7, height: 7))
                context.fill(hub2, with: .color(recommendation.color))
            }
            .frame(height: 120)
            .frame(maxWidth: 240)

            HStack {
                Text("Sell").foregroundStyle(Recommendation.sell.color)
                Spacer()
                Text("Neutral").foregroundStyle(.secondary)
                Spacer()
                Text("Buy").foregroundStyle(Recommendation.buy.color)
            }
            .font(.caption2.weight(.medium))
            .frame(maxWidth: 240)

            Text(recommendation.label)
                .font(.title2.bold())
                .foregroundStyle(recommendation.color)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Technical rating: \(recommendation.label)")
    }
}

#Preview {
    VStack(spacing: 30) {
        RatingGaugeView(average: 0.7, recommendation: .strongBuy)
        RatingGaugeView(average: -0.3, recommendation: .sell)
    }
    .padding()
}
