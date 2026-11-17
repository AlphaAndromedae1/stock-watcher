import SwiftUI

struct SignalPill: View {
    let signal: Signal
    var body: some View {
        Text(signal.label.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(signal.color, in: Capsule())
    }
}

struct IndicatorRow: View {
    let result: IndicatorResult
    var body: some View {
        HStack {
            Text(result.name)
                .font(.subheadline)
            Spacer()
            if let v = result.value {
                Text(Fmt.number(v, decimals: 2))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 70, alignment: .trailing)
            }
            SignalPill(signal: result.signal)
                .frame(width: 66, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

/// Buy / Neutral / Sell tally bar for a rating group.
struct TallyRow: View {
    let group: RatingGroup
    var body: some View {
        HStack(spacing: 16) {
            tally("Sell", group.sellCount, Recommendation.sell.color)
            tally("Neutral", group.neutralCount, Recommendation.neutral.color)
            tally("Buy", group.buyCount, Recommendation.buy.color)
        }
    }

    private func tally(_ label: String, _ count: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
