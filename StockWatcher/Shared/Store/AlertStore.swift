import Foundation

/// A user-defined alert on a symbol.
public struct PriceAlert: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var symbol: String
    public var name: String
    public var kind: Kind
    public var threshold: Double     // used by price alerts; 0 for rating alerts
    public var enabled: Bool
    public var lastTriggered: Date?

    public enum Kind: String, Codable, Sendable, CaseIterable {
        case priceAbove, priceBelow, ratingBuy, ratingSell
    }

    public init(id: UUID = UUID(), symbol: String, name: String, kind: Kind,
                threshold: Double = 0, enabled: Bool = true, lastTriggered: Date? = nil) {
        self.id = id
        self.symbol = symbol.uppercased()
        self.name = name
        self.kind = kind
        self.threshold = threshold
        self.enabled = enabled
        self.lastTriggered = lastTriggered
    }

    public var symbolDisplay: String {
        symbol.replacingOccurrences(of: ".TO", with: "").replacingOccurrences(of: ".V", with: "")
    }

    public var describe: String {
        switch kind {
        case .priceAbove: return "Price at/above \(Fmt.price(threshold))"
        case .priceBelow: return "Price at/below \(Fmt.price(threshold))"
        case .ratingBuy:  return "Rating turns Buy"
        case .ratingSell: return "Rating turns Sell"
        }
    }
}

/// Persists alerts in the App Group.
public final class AlertStore: @unchecked Sendable {
    public static let shared = AlertStore()
    private static let key = "alerts.v1"

    private let defaults: UserDefaults
    public init() {
        defaults = UserDefaults(suiteName: WatchlistStore.appGroupID) ?? .standard
    }

    public func all() -> [PriceAlert] {
        guard let data = defaults.data(forKey: Self.key),
              let items = try? JSONDecoder().decode([PriceAlert].self, from: data) else { return [] }
        return items
    }

    public func alerts(for symbol: String) -> [PriceAlert] {
        all().filter { $0.symbol == symbol.uppercased() }
    }

    public func add(_ alert: PriceAlert) {
        var items = all()
        items.append(alert)
        persist(items)
    }

    public func update(_ alert: PriceAlert) {
        var items = all()
        if let i = items.firstIndex(where: { $0.id == alert.id }) {
            items[i] = alert
            persist(items)
        }
    }

    public func remove(id: UUID) {
        persist(all().filter { $0.id != id })
    }

    /// Ensures a single rating alert of a kind exists/absent for a symbol.
    public func setRatingAlert(symbol: String, name: String, kind: PriceAlert.Kind, on: Bool) {
        var items = all()
        items.removeAll { $0.symbol == symbol.uppercased() && $0.kind == kind }
        if on {
            items.append(PriceAlert(symbol: symbol, name: name, kind: kind))
        }
        persist(items)
    }

    public func hasRatingAlert(symbol: String, kind: PriceAlert.Kind) -> Bool {
        all().contains { $0.symbol == symbol.uppercased() && $0.kind == kind }
    }

    private func persist(_ items: [PriceAlert]) {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
