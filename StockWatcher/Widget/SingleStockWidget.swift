import WidgetKit
import SwiftUI
import AppIntents
import UIKit

// MARK: - Configuration intent

struct SelectStockIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Stock"

    /// Yahoo symbol, e.g. "SHOP.TO". Empty uses the top of your watchlist.
    @Parameter(title: "Symbol (e.g. SHOP.TO)")
    var symbol: String?
}

// MARK: - Entry

struct SingleStockEntry: TimelineEntry {
    let date: Date
    let symbol: String      // display, e.g. "RY"
    let name: String
    let price: Double
    let changePercent: Double
    let isUp: Bool
    let score: Int?
    let band: CompositeEvaluator.Band?
    let spark: [Double]
    let hasData: Bool

    static let sample = SingleStockEntry(
        date: Date(), symbol: "RY", name: "Royal Bank of Canada",
        price: 176.42, changePercent: 0.82, isUp: true, score: 74, band: .bullish,
        spark: (0..<24).map { 160 + Double($0) * 0.7 + (($0 % 3 == 0) ? 1.5 : -1.0) },
        hasData: true)
}

// MARK: - Provider

struct SingleStockProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SingleStockEntry { .sample }

    func snapshot(for configuration: SelectStockIntent, in context: Context) async -> SingleStockEntry {
        if context.isPreview { return .sample }
        return await Self.load(symbol: configuration.symbol)
    }

    func timeline(for configuration: SelectStockIntent, in context: Context) async -> Timeline<SingleStockEntry> {
        let entry = await Self.load(symbol: configuration.symbol)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(next))
    }

    static func load(symbol configured: String?) async -> SingleStockEntry {
        let symbol = (configured?.isEmpty == false ? configured! : WatchlistStore.shared.load().first?.symbol) ?? "RY.TO"
        let display = symbol.replacingOccurrences(of: ".TO", with: "").replacingOccurrences(of: ".V", with: "")
        let name = TSXCatalog.name(for: symbol) ?? display

        guard let result = try? await YahooService.shared.fetchCandles(symbol: symbol, range: .oneYear),
              !result.candles.isEmpty else {
            return SingleStockEntry(date: Date(), symbol: display, name: name, price: 0,
                                    changePercent: 0, isUp: true, score: nil, band: nil,
                                    spark: [], hasData: false)
        }
        let quote = YahooService.quote(from: result.meta, fallbackSymbol: symbol)
        let rating = TechnicalAnalyzer.analyze(result.candles)
        let composite = CompositeEvaluator.evaluate(technical: rating, fundamentals: Fundamentals(), quote: quote)
        let spark = Array(result.candles.suffix(30).map(\.close))
        return SingleStockEntry(date: Date(), symbol: display, name: name, price: quote.price,
                                changePercent: quote.changePercent, isUp: quote.isUp,
                                score: composite?.score, band: composite?.band,
                                spark: spark, hasData: true)
    }
}

// MARK: - Widget

struct SingleStockWidget: Widget {
    let kind = "SingleStockWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectStockIntent.self, provider: SingleStockProvider()) { entry in
            SingleStockWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("Single Stock")
        .description("Track one stock with price, daily change and its Stock Watcher Score.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - View

struct SingleStockWidgetView: View {
    let entry: SingleStockEntry

    private func bandColor(_ b: CompositeEvaluator.Band) -> Color {
        switch b {
        case .veryBullish: return Color(red: 0.11, green: 0.70, blue: 0.42)
        case .bullish:     return Color(red: 0.30, green: 0.78, blue: 0.47)
        case .mixed:       return Color(red: 0.55, green: 0.57, blue: 0.62)
        case .bearish:     return Color(red: 0.93, green: 0.49, blue: 0.33)
        case .veryBearish: return Color(red: 0.90, green: 0.26, blue: 0.29)
        }
    }

    private var changeColor: Color {
        entry.isUp ? Color(red: 0.20, green: 0.72, blue: 0.45) : Color(red: 0.90, green: 0.30, blue: 0.33)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.symbol).font(.headline.bold())
                    Text(entry.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if let score = entry.score, let band = entry.band {
                    Text("\(score)")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(bandColor(band), in: Capsule())
                }
            }

            if entry.hasData {
                Text(Fmt.number(entry.price))
                    .font(.title2.monospacedDigit().bold())
                HStack(spacing: 3) {
                    Image(systemName: entry.isUp ? "arrow.up" : "arrow.down").font(.caption2.bold())
                    Text(Fmt.signedPercent(entry.changePercent)).font(.caption.monospacedDigit().bold())
                }
                .foregroundStyle(changeColor)
            } else {
                Text("—").foregroundStyle(.secondary)
            }

            Spacer(minLength: 2)
            Sparkline(values: entry.spark, color: changeColor)
                .frame(height: 28)
        }
    }
}

/// A minimal sparkline drawn with a Path (no Charts dependency in the widget).
struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            if pts.count >= 2 {
                Path { p in
                    p.move(to: pts[0])
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.6, linejoin: .round))
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count >= 2, let lo = values.min(), let hi = values.max(), hi > lo else { return [] }
        let stepX = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            let x = CGFloat(i) * stepX
            let y = size.height - CGFloat((v - lo) / (hi - lo)) * size.height
            return CGPoint(x: x, y: y)
        }
    }
}
