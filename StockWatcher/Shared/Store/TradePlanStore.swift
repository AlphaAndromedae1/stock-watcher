import Foundation

/// A simple exit plan for a stock: a target to take profit and a stop/review
/// price. Used by the odds simulator (probability of hitting each) and shown
/// on the detail screen with its reward:risk.
public struct TradePlan: Codable, Equatable, Sendable {
    public var target: Double?
    public var stop: Double?

    public init(target: Double? = nil, stop: Double? = nil) {
        self.target = target
        self.stop = stop
    }

    public var isEmpty: Bool { target == nil && stop == nil }

    /// Reward:risk from an entry price (target above, stop below).
    public func rewardRisk(entry: Double) -> Double? {
        guard let target, let stop, entry > stop, target > entry else { return nil }
        let risk = entry - stop
        guard risk > 0 else { return nil }
        return (target - entry) / risk
    }
}

public final class TradePlanStore: @unchecked Sendable {
    public static let shared = TradePlanStore()
    private static let key = "tradePlans.v1"

    private let defaults: UserDefaults
    public init() {
        defaults = UserDefaults(suiteName: WatchlistStore.appGroupID) ?? .standard
    }

    private func all() -> [String: TradePlan] {
        guard let data = defaults.data(forKey: Self.key),
              let dict = try? JSONDecoder().decode([String: TradePlan].self, from: data) else { return [:] }
        return dict
    }

    public func plan(for symbol: String) -> TradePlan? {
        let p = all()[symbol.uppercased()]
        return (p?.isEmpty ?? true) ? nil : p
    }

    public func save(_ plan: TradePlan, for symbol: String) {
        var dict = all()
        if plan.isEmpty {
            dict[symbol.uppercased()] = nil
        } else {
            dict[symbol.uppercased()] = plan
        }
        if let data = try? JSONEncoder().encode(dict) {
            defaults.set(data, forKey: Self.key)
        }
    }

    public func remove(symbol: String) {
        var dict = all()
        dict[symbol.uppercased()] = nil
        if let data = try? JSONEncoder().encode(dict) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
