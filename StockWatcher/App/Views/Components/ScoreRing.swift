import SwiftUI

/// A circular 0–100 score dial used by the Stock Watcher Score card.
struct ScoreRing: View {
    let score: Int
    let color: Color

    private var fraction: CGFloat {
        CGFloat(min(max(score, 0), 100)) / 100
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: 10)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.title.bold().monospacedDigit())
                Text("/100")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 92, height: 92)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stock Watcher Score \(score) out of 100")
    }
}

#Preview {
    HStack(spacing: 20) {
        ScoreRing(score: 78, color: .green)
        ScoreRing(score: 44, color: .gray)
    }
    .padding()
}
