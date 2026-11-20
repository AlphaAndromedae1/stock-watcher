import SwiftUI

private let upColor = Color(red: 0.20, green: 0.72, blue: 0.45)
private let downColor = Color(red: 0.90, green: 0.30, blue: 0.33)

/// A monogram "logo" badge: ticker initials in a deterministic colored circle.
/// (Real brand logos have no reliable free source for TSX names/ETFs.)
struct LogoBadge: View {
    let symbol: String
    var size: CGFloat = 26

    private var initials: String { String(symbol.prefix(2)).uppercased() }

    private var color: Color {
        let palette: [Color] = [.blue, .indigo, .teal, .orange, .pink, .purple, .green, .cyan, .mint]
        var hash = 0
        for scalar in symbol.unicodeScalars { hash = hash &* 31 &+ Int(scalar.value) }
        return palette[abs(hash) % palette.count]
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
    }
}

/// A compact zero-centered MACD histogram (green above zero, red below).
struct MiniMACD: View {
    let values: [Double]

    var body: some View {
        Canvas { context, size in
            guard !values.isEmpty else { return }
            let maxMag = max(values.map { abs($0) }.max() ?? 1, 0.0001)
            let barWidth = size.width / CGFloat(values.count)
            let mid = size.height / 2
            for (i, v) in values.enumerated() {
                let h = CGFloat(abs(v) / maxMag) * (size.height / 2)
                let x = CGFloat(i) * barWidth
                let rect: CGRect = v >= 0
                    ? CGRect(x: x, y: mid - h, width: max(barWidth - 1, 1), height: max(h, 0.5))
                    : CGRect(x: x, y: mid, width: max(barWidth - 1, 1), height: max(h, 0.5))
                context.fill(Path(rect), with: .color(v >= 0 ? upColor : downColor))
            }
        }
    }
}
