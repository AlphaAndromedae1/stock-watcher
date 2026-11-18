import Foundation

/// A position the user owns: share count and average per-share cost.
public struct Holding: Codable, Equatable, Sendable, Identifiable {
    public var symbol: String
    public var shares: Double
    public var costBasis: Double     // average cost per share
    public var id: String { symbol }

    public init(symbol: String, shares: Double, costBasis: Double) {
        self.symbol = symbol.uppercased()
        self.shares = shares
        self.costBasis = costBasis
    }

    public var cost: Double { shares * costBasis }
    public func marketValue(at price: Double) -> Double { shares * price }
    public func gain(at price: Double) -> Double { marketValue(at: price) - cost }
    public func gainPercent(at price: Double) -> Double {
        costBasis > 0 ? (price - costBasis) / costBasis * 100 : 0
    }
}

/// Persists holdings in the App Group (shared with the widget).
public final class HoldingsStore: @unchecked Sendable {
    public static let shared = HoldingsStore()
    private static let key = "holdings.v1"

    private let defaults: UserDefaults
    public init() {
        defaults = UserDefaults(suiteName: WatchlistStore.appGroupID) ?? .standard
    }

    public func all() -> [Holding] {
        guard let data = defaults.data(forKey: Self.key),
              let items = try? JSONDecoder().decode([Holding].self, from: data) else { return [] }
        return items
    }

    public func holding(symbol: String) -> Holding? {
        all().first { $0.symbol == symbol.uppercased() }
    }

    public func save(_ holding: Holding) {
        var items = all().filter { $0.symbol != holding.symbol }
        if holding.shares > 0 { items.append(holding) }
        persist(items)
    }

    public func remove(symbol: String) {
        persist(all().filter { $0.symbol != symbol.uppercased() })
    }

    private func persist(_ items: [Holding]) {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
