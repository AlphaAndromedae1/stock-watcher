import Foundation

/// Persists the watchlist in the shared App Group container so the app and the
/// widget read and write the very same list.
///
/// IMPORTANT: `appGroupID` must match the `com.apple.security.application-groups`
/// value in BOTH entitlements files. If you rename it, rename it in all three places.
public final class WatchlistStore: @unchecked Sendable {
    public static let appGroupID = "group.com.stockwatcher.app"
    private static let key = "watchlist.v1"

    public static let shared = WatchlistStore()

    private let defaults: UserDefaults

    public init() {
        // Falls back to standard defaults if the App Group isn't configured yet,
        // so the app still runs in the Simulator before signing is set up.
        defaults = UserDefaults(suiteName: WatchlistStore.appGroupID) ?? .standard
    }

    public func load() -> [WatchItem] {
        guard let data = defaults.data(forKey: Self.key) else {
            return Self.defaultWatchlist
        }
        guard let items = try? JSONDecoder().decode([WatchItem].self, from: data) else {
            return Self.defaultWatchlist
        }
        return items
    }

    public func save(_ items: [WatchItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: Self.key)
    }

    @discardableResult
    public func add(_ item: WatchItem) -> [WatchItem] {
        var items = load()
        guard !items.contains(where: { $0.symbol == item.symbol }) else { return items }
        items.append(item)
        save(items)
        return items
    }

    @discardableResult
    public func remove(symbol: String) -> [WatchItem] {
        var items = load().filter { $0.symbol != symbol.uppercased() }
        save(items)
        return items
    }

    public func contains(symbol: String) -> Bool {
        load().contains { $0.symbol == symbol.uppercased() }
    }

    // Note: reordering is done in WatchlistViewModel (app target), which can
    // use SwiftUI's MutableCollection.move(fromOffsets:toOffset:). That method
    // is NOT in the standard library, so it must not be referenced from Shared
    // code — the SwiftUI-free test target would fail to link.

    /// Fixed, self-contained symbol list the widgets display (no App Group
    /// needed). Edit this to change what the widgets show.
    public static let widgetSymbols: [WatchItem] = [
        WatchItem(symbol: "XEQT.TO", name: "iShares Core Equity ETF"),
        WatchItem(symbol: "CNQ.TO",  name: "Canadian Natural Resources"),
        WatchItem(symbol: "SU.TO",   name: "Suncor Energy"),
        WatchItem(symbol: "CHPS.TO", name: "CHPS")
    ]

    /// A sensible starter list of large, liquid TSX names.
    public static let defaultWatchlist: [WatchItem] = [
        WatchItem(symbol: "RY.TO",  name: "Royal Bank of Canada"),
        WatchItem(symbol: "SHOP.TO", name: "Shopify Inc."),
        WatchItem(symbol: "ENB.TO", name: "Enbridge Inc."),
        WatchItem(symbol: "CNQ.TO", name: "Canadian Natural Resources"),
        WatchItem(symbol: "TD.TO",  name: "Toronto-Dominion Bank")
    ]
}
