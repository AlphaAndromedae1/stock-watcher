import SwiftUI

private let upColor = Pantone.emerald
private let downColor = Pantone.livingCoral

/// A monogram "logo" badge: ticker initials in a PANTONE-colored circle, with a
/// soft drop shadow for a little depth. (Real brand logos have no reliable free
/// source for TSX names / ETFs.)
struct LogoBadge: View {
    let symbol: String
    var size: CGFloat = 26

    private var initials: String {
        symbol.hasPrefix("Gold") ? "AU" : String(symbol.prefix(2)).uppercased()
    }

    private var color: Color {
        if symbol.hasPrefix("Gold") { return Pantone.marigold }
        let palette: [Color] = [
            Pantone.classicBlue, Pantone.emerald, Pantone.aquaSky, Pantone.tangerine,
            Pantone.vivaMagenta, Pantone.greenery, Pantone.illuminating
        ]
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
            .overlay(Circle().strokeBorder(.white.opacity(0.28), lineWidth: 0.5))
            .shadow(color: color.opacity(0.45), radius: 2.5, x: 0, y: 1.5)
    }
}

/// A compact zero-centered MACD histogram (green above zero, coral below).
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
