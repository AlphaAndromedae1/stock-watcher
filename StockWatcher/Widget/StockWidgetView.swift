import WidgetKit
import SwiftUI
import UIKit

private extension Color {
    static func change(_ up: Bool) -> Color { up ? Pantone.emerald : Pantone.livingCoral }

    static func band(_ b: CompositeEvaluator.Band) -> Color {
        switch b {
        case .veryBullish: return Pantone.emerald
        case .bullish:     return Pantone.greenery
        case .mixed:       return Pantone.ultimateGray
        case .bearish:     return Pantone.tangerine
        case .veryBearish: return Pantone.flameScarlet
        }
    }

    static func mood(_ b: MarketMood.Band) -> Color {
        switch b {
        case .calm:    return Pantone.emerald
        case .normal:  return Pantone.greenery
        case .guarded: return Pantone.illuminating
        case .fearful: return Pantone.tangerine
        case .panic:   return Pantone.flameScarlet
        }
    }
}

struct StockWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StockEntry

    var body: some View {
        content
            .padding(contentPadding)
            .containerBackground(for: .widget) { backgroundStyle }
    }

    /// Extra breathing room from the card edge (TradingView-style). The lock-
    /// screen accessory stays flush since its space is tight.
    private var contentPadding: EdgeInsets {
        family == .accessoryRectangular
            ? EdgeInsets()
            : EdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 5)
    }

    @ViewBuilder
    private var backgroundStyle: some View {
        if family == .accessoryRectangular {
            Color.clear
        } else {
            // Frosted "liquid glass" background: material + a PANTONE tint wash
            // + a diagonal sheen for a little depth.
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(colors: [Pantone.classicBlue.opacity(0.20), Color.clear,
                                        Pantone.emerald.opacity(0.12)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                LinearGradient(colors: [Color.white.opacity(0.10), Color.clear, Color.black.opacity(0.16)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if entry.rows.isEmpty {
            emptyView
        } else {
            switch family {
            case .systemSmall: smallView
            case .accessoryRectangular: accessoryView
            default: listView
            }
        }
    }

    // MARK: Empty

    private var emptyView: some View {
        VStack(spacing: 4) {
            Image(systemName: "star")
            Text("Add stocks in\nStock Watcher")
                .font(.caption2)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
    }

    // MARK: Small (top 2)

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 2)
            ForEach(entry.rows.prefix(2)) { row in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(row.symbol).font(.footnote.bold())
                        Spacer(minLength: 2)
                        scoreChip(row)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.hasData ? Fmt.number(row.price) : "—")
                            .font(.title3.monospacedDigit().weight(.semibold))
                        Spacer(minLength: 2)
                        changeBadge(row)
                    }
                    if row.hasData && row.spark.count > 1 {
                        MiniSparkline(values: row.spark, up: row.isUp)
                            .frame(height: 15)
                    }
                }
                if row.id != entry.rows.prefix(2).last?.id {
                    Spacer(minLength: 7)
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(entry.rows.first.flatMap { StockWatcherURL.stock($0.fullSymbol) })
    }

    // MARK: Medium / Large list

    private var listView: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 6)
            ForEach(Array(entry.rows.enumerated()), id: \.element.id) { index, row in
                if let url = StockWatcherURL.stock(row.fullSymbol) {
                    Link(destination: url) { rowView(row) }
                } else {
                    rowView(row)
                }
                if index < entry.rows.count - 1 {
                    Divider().opacity(0.22).padding(.vertical, 7)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func rowView(_ row: WidgetRow) -> some View {
        HStack(spacing: 8) {
            LogoBadge(symbol: row.symbol, size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.symbol)
                    .font(.subheadline.bold())
                Text(row.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 4)
            if row.hasData && row.spark.count > 1 {
                MiniSparkline(values: row.spark, up: row.isUp)
                    .frame(width: 46, height: 26)
            }
            VStack(alignment: .trailing, spacing: 1) {
                Text(row.hasData ? Fmt.number(row.price) : "—")
                    .font(.headline.monospacedDigit())
                changeBadge(row)
            }
            scoreChip(row)
        }
    }

    @ViewBuilder
    private func scoreChip(_ row: WidgetRow) -> some View {
        if let score = row.score, let band = row.band {
            Text("\(score)")
                .font(.caption2.monospacedDigit().bold())
                .foregroundStyle(.white)
                .frame(minWidth: 15)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.band(band).gradient, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                .shadow(color: Color.band(band).opacity(0.5), radius: 2.5, x: 0, y: 1.5)
                .accessibilityLabel("Score \(score), \(band.label)")
        } else {
            Color.clear.frame(width: 1)
        }
    }

    // MARK: Lock-screen accessory

    private var accessoryView: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(entry.rows.prefix(2)) { row in
                HStack {
                    Text(row.symbol).font(.caption2.bold())
                    Spacer()
                    Text(row.hasData ? Fmt.number(row.price) : "—").font(.caption2.monospacedDigit())
                    Text(row.hasData ? Fmt.signedPercent(row.changePercent) : "")
                        .font(.caption2.monospacedDigit())
                }
            }
        }
        .widgetAccentable()
    }

    // MARK: Pieces

    private var header: some View {
        let isOpen = MarketHours.isTSXOpen(at: entry.date)
        return HStack(spacing: 6) {
            Circle()
                .fill(isOpen ? Color(red: 0.20, green: 0.72, blue: 0.45) : Color.secondary)
                .frame(width: 6, height: 6)
            Text(isOpen ? "TSX · Open" : "TSX · Closed")
                .font(.caption2.bold()).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            if let mood = entry.mood, mood.headline != nil {
                moodPill(mood)
            } else {
                Text(Fmt.time(entry.date)).font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func moodPill(_ mood: MarketMood) -> some View {
        if let value = mood.headline, let band = mood.band {
            HStack(spacing: 4) {
                Circle().fill(Color.mood(band)).frame(width: 6, height: 6)
                if family != .systemSmall {
                    Text(band.label).font(.caption2.bold()).foregroundStyle(Color.mood(band))
                }
                Text("\(mood.headlineName) Index \(Fmt.number(value, decimals: value >= 30 ? 0 : 1))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityLabel("Market mood \(band.label), \(mood.headlineName) \(Int(value))")
        }
    }

    private func changeBadge(_ row: WidgetRow) -> some View {
        Group {
            if row.hasData {
                HStack(spacing: 2) {
                    Image(systemName: row.isUp ? "arrow.up" : "arrow.down").font(.system(size: 8).bold())
                    Text(Fmt.signedPercent(row.changePercent)).font(.caption2.monospacedDigit().bold())
                }
                .foregroundStyle(Color.change(row.isUp))
            } else {
                Text("—").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
