import WidgetKit
import SwiftUI
import UIKit

private extension Color {
    static func change(_ up: Bool) -> Color {
        up ? Color(red: 0.20, green: 0.72, blue: 0.45) : Color(red: 0.90, green: 0.30, blue: 0.33)
    }

    static func band(_ b: CompositeEvaluator.Band) -> Color {
        switch b {
        case .veryBullish: return Color(red: 0.11, green: 0.70, blue: 0.42)
        case .bullish:     return Color(red: 0.30, green: 0.78, blue: 0.47)
        case .mixed:       return Color(red: 0.55, green: 0.57, blue: 0.62)
        case .bearish:     return Color(red: 0.93, green: 0.49, blue: 0.33)
        case .veryBearish: return Color(red: 0.90, green: 0.26, blue: 0.29)
        }
    }

    static func mood(_ b: MarketMood.Band) -> Color {
        switch b {
        case .calm:    return Color(red: 0.20, green: 0.72, blue: 0.45)
        case .normal:  return Color(red: 0.36, green: 0.73, blue: 0.55)
        case .guarded: return Color(red: 0.92, green: 0.70, blue: 0.25)
        case .fearful: return Color(red: 0.93, green: 0.49, blue: 0.33)
        case .panic:   return Color(red: 0.90, green: 0.26, blue: 0.29)
        }
    }
}

struct StockWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StockEntry

    var body: some View {
        content
            .containerBackground(for: .widget) { backgroundStyle }
    }

    @ViewBuilder
    private var backgroundStyle: some View {
        if family == .accessoryRectangular {
            Color.clear
        } else {
            LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                           startPoint: .top, endPoint: .bottom)
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
                VStack(alignment: .leading, spacing: 1) {
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
                }
                if row.id != entry.rows.prefix(2).last?.id {
                    Spacer(minLength: 6)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Medium / Large list

    private var listView: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 6)
            ForEach(Array(entry.rows.enumerated()), id: \.element.id) { index, row in
                rowView(row)
                if index < entry.rows.count - 1 {
                    Divider().opacity(0.22).padding(.vertical, 5)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func rowView(_ row: WidgetRow) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.symbol)
                    .font(.subheadline.bold())
                Text(row.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(row.hasData ? Fmt.number(row.price) : "—")
                    .font(.subheadline.monospacedDigit())
                HStack(spacing: 5) {
                    changeBadge(row)
                    scoreChip(row)
                }
            }
        }
    }

    @ViewBuilder
    private func scoreChip(_ row: WidgetRow) -> some View {
        if let score = row.score, let band = row.band {
            Text("\(score)")
                .font(.caption2.monospacedDigit().bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.band(band), in: Capsule())
                .accessibilityLabel("Score \(score), \(band.label)")
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
        HStack(spacing: 6) {
            Text("TSX Watch").font(.caption2.bold()).foregroundStyle(.secondary)
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
                Text("\(mood.headlineName) \(Fmt.number(value, decimals: value >= 30 ? 0 : 1))")
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
