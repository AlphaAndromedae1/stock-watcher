import WidgetKit
import SwiftUI

@main
struct StockWidgetBundle: WidgetBundle {
    var body: some Widget {
        StockWidget()
        SingleStockWidget()
    }
}

struct StockWidget: Widget {
    let kind = "StockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StockProvider()) { entry in
            StockWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("TSX Watchlist")
        .description("Track your watchlist's prices and daily change at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

#Preview(as: .systemMedium) {
    StockWidget()
} timeline: {
    StockEntry.sample
}
