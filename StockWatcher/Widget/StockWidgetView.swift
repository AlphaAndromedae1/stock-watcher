import WidgetKit
import SwiftUI
import UIKit

private extension Color {
    static func change(_ up: Bool) -> Color {
        up ? Color(red: 0.20, green: 0.72, blue: 0.45) : Color(red: 0.90, green: 0.30, blue: 0.33)
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

    // MARK: Small (shows top 2)

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ForEach(entry.rows.prefix(2)) { row in
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.symbol).font(.caption.bold())
                    HStack(spacing: 4) {
                        Text(row.hasData ? Fmt.number(row.price) : "—")
                            .font(.footnote.monospacedDigit().bold())
                        Spacer(minLength: 2)
                        changeBadge(row)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Medium / Large list

    private var listView: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            ForEach(entry.rows) { row in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(row.symbol).font(.subheadline.bold())
                        Text(row.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(row.hasData ? Fmt.number(row.price) : "—")
                        .font(.subheadline.monospacedDigit())
                    changeBadge(row).frame(width: 74, alignment: .trailing)
                }
                if row.id != entry.rows.last?.id {
                    Divider().opacity(0.5)
                }
            }
            Spacer(minLength: 0)
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
        HStack {
            Text("TSX Watch").font(.caption2.bold()).foregroundStyle(.secondary)
            Spacer()
            Text(Fmt.time(entry.date)).font(.caption2).foregroundStyle(.tertiary)
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
