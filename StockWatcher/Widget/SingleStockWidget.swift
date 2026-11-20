import WidgetKit
import SwiftUI
import UIKit

// A "Top Pick" single-stock widget. It uses a plain StaticConfiguration +
// TimelineProvider (no AppIntents): AppIntent-configured widgets frequently get
// stuck on their placeholder on iOS 17 / sideloaded builds, so this reliably
// loads. It features the highest Stock Watcher Score in the watchlist.

// MARK: - Entry

struct SingleStockEntry: TimelineEntry {
    let date: Date
    let symbol: String      // display, e.g. "RY"
    let fullSymbol: String  // Yahoo symbol, e.g. "RY.TO" (for deep links)
    let name: String
    let price: Double
    let changePercent: Double
    let isUp: Bool
    let score: Int?
    let band: CompositeEvaluator.Band?
    let macd: [Double]      // recent MACD histogram values
    let hasData: Bool

    static let sampleMACD: [Double] = [
        -0.4, -0.3, -0.2, -0.1, 0.05, 0.15, 0.3, 0.25, 0.35, 0.5, 0.45, 0.6,
        0.55, 0.7, 0.65, 0.8, 0.7, 0.9, 0.85, 1.0, 0.9, 1.05, 0.95, 1.1
    ]

    static let sample = SingleStockEntry(
        date: Date(), symbol: "RY", fullSymbol: "RY.TO", name: "Royal Bank of Canada",
        price: 176.42, changePercent: 0.82, isUp: true, score: 74, band: .bullish,
        macd: sampleMACD, hasData: true)

    static func noData(_ display: String = "—", name: String = "No data") -> SingleStockEntry {
        SingleStockEntry(date: Date(), symbol: display, fullSymbol: display, name: name, price: 0,
                         changePercent: 0, isUp: true, score: nil, band: nil,
                         macd: [], hasData: false)
    }
}

// MARK: - Provider

struct TopPickProvider: TimelineProvider {
    func placeholder(in context: Context) -> SingleStockEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (SingleStockEntry) -> Void) {
        if context.isPreview { completion(.sample); return }
        Task { completion(await Self.load()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SingleStockEntry>) -> Void) {
        Task {
            let entry = await Self.load()
            let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    static func load() async -> SingleStockEntry {
        // If the user picked a specific stock in the app, show that one.
        if let featured = SettingsStore.shared.featuredSymbol,
           let entry = await loadOne(symbol: featured) {
            return entry
        }

        // Otherwise feature the highest Stock Watcher Score among the widget list.
        let symbols = WatchlistStore.widgetSymbols.map(\.symbol)
        guard !symbols.isEmpty else { return .noData() }

        let entries = await withTaskGroup(of: SingleStockEntry?.self) { group -> [SingleStockEntry] in
            for symbol in symbols {
                group.addTask { await loadOne(symbol: symbol) }
            }
            var out: [SingleStockEntry] = []
            for await entry in group {
                if let entry, entry.hasData { out.append(entry) }
            }
            return out
        }

        // Feature the highest Stock Watcher Score.
        return entries.max(by: { ($0.score ?? -1) < ($1.score ?? -1) }) ?? .noData()
    }

    static func loadOne(symbol: String) async -> SingleStockEntry? {
        let display = symbol.replacingOccurrences(of: ".TO", with: "").replacingOccurrences(of: ".V", with: "")
        let name = TSXCatalog.name(for: symbol) ?? display
        guard let result = try? await YahooService.shared.fetchCandles(symbol: symbol, range: .oneYear),
              !result.candles.isEmpty else { return nil }
        let quote = YahooService.quote(from: result.meta, fallbackSymbol: symbol)
        let rating = TechnicalAnalyzer.analyze(result.candles)
        let composite = CompositeEvaluator.evaluate(technical: rating, fundamentals: Fundamentals(), quote: quote)
        let histogram = Indicators.macd(result.candles.closes).histogram
        let macd = Array(histogram.filter { $0.isFinite }.suffix(30))
        return SingleStockEntry(date: Date(), symbol: display, fullSymbol: symbol, name: name, price: quote.price,
                                changePercent: quote.changePercent, isUp: quote.isUp,
                                score: composite?.score, band: composite?.band,
                                macd: macd, hasData: true)
    }
}

// MARK: - Widget

struct SingleStockWidget: Widget {
    let kind = "SingleStockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TopPickProvider()) { entry in
            SingleStockWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        LinearGradient(colors: [Color.white.opacity(0.12), Color.clear, Color.black.opacity(0.10)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
        }
        .configurationDisplayName("Featured Stock")
        .description("Shows the stock you choose in the app, or the highest Stock Watcher Score.")
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
            HStack(alignment: .top, spacing: 8) {
                LogoBadge(symbol: entry.symbol, size: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text("FEATURED").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                    Text(entry.symbol).font(.title3.bold())
                    Text(entry.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if let score = entry.score, let band = entry.band {
                    Text("\(score)")
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(bandColor(band).gradient, in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
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
                Text("Add stocks in the app").font(.caption).foregroundStyle(.secondary)
            }

            Spacer(minLength: 2)
            Text("MACD").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            MiniMACD(values: entry.macd)
                .frame(height: 26)
        }
        .widgetURL(StockWatcherURL.stock(entry.fullSymbol))
    }
}
