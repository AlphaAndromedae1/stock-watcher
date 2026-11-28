import Foundation

/// User preferences, shared with the widget via the App Group.
public final class SettingsStore: @unchecked Sendable {
    public static let shared = SettingsStore()

    private let defaults: UserDefaults
    public init() {
        defaults = UserDefaults(suiteName: WatchlistStore.appGroupID) ?? .standard
    }

    private enum Key {
        static let refreshMinutes = "settings.refreshMinutes"
        static let defaultRange = "settings.defaultRange"
        static let wTechnical = "settings.weight.technical"
        static let wFundamental = "settings.weight.fundamental"
        static let wAnalyst = "settings.weight.analyst"
        static let wTarget = "settings.weight.target"
        static let alertsEnabled = "settings.alertsEnabled"
        static let vixAlertEnabled = "settings.vixAlertEnabled"
        static let lastVixAlert = "settings.lastVixAlert"
        static let featuredSymbol = "settings.featuredSymbol"
        static let accountSize = "settings.accountSize"
        static let maxRiskPerTrade = "settings.maxRiskPerTrade"
        static let taxAccount = "settings.taxAccount"
    }

    /// The account holdings sit in. Used only for the tax notes on the Quant Checks card.
    public var taxAccount: TaxAccount {
        get {
            if let raw = defaults.string(forKey: Key.taxAccount), let a = TaxAccount(rawValue: raw) {
                return a
            }
            return .nonRegistered
        }
        set { defaults.set(newValue.rawValue, forKey: Key.taxAccount) }
    }

    public var accountSize: Double {
        get { doubleOr(Key.accountSize, 5000) }
        set { defaults.set(newValue, forKey: Key.accountSize) }
    }

    public var maxRiskPerTrade: Double {
        get { doubleOr(Key.maxRiskPerTrade, 50) }
        set { defaults.set(newValue, forKey: Key.maxRiskPerTrade) }
    }

    /// The stock the single-stock widget should feature. nil/empty = auto (Top Pick).
    public var featuredSymbol: String? {
        get {
            let s = defaults.string(forKey: Key.featuredSymbol) ?? ""
            return s.isEmpty ? nil : s
        }
        set { defaults.set(newValue ?? "", forKey: Key.featuredSymbol) }
    }

    public var refreshMinutes: Int {
        get {
            let v = defaults.object(forKey: Key.refreshMinutes) as? Int ?? 30
            return min(max(v, 5), 240)
        }
        set { defaults.set(min(max(newValue, 5), 240), forKey: Key.refreshMinutes) }
    }

    public var defaultRange: ChartRange {
        get {
            if let raw = defaults.string(forKey: Key.defaultRange), let r = ChartRange(rawValue: raw) {
                return r
            }
            return .oneYear
        }
        set { defaults.set(newValue.rawValue, forKey: Key.defaultRange) }
    }

    public var weights: CompositeEvaluator.Weights {
        get {
            CompositeEvaluator.Weights(
                technical: doubleOr(Key.wTechnical, 0.40),
                fundamental: doubleOr(Key.wFundamental, 0.40),
                analyst: doubleOr(Key.wAnalyst, 0.15),
                target: doubleOr(Key.wTarget, 0.05))
        }
        set {
            defaults.set(newValue.technical, forKey: Key.wTechnical)
            defaults.set(newValue.fundamental, forKey: Key.wFundamental)
            defaults.set(newValue.analyst, forKey: Key.wAnalyst)
            defaults.set(newValue.target, forKey: Key.wTarget)
        }
    }

    public var alertsEnabled: Bool {
        get { defaults.object(forKey: Key.alertsEnabled) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.alertsEnabled) }
    }

    public var vixAlertEnabled: Bool {
        get { defaults.object(forKey: Key.vixAlertEnabled) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.vixAlertEnabled) }
    }

    public var lastVixAlert: Date? {
        get { defaults.object(forKey: Key.lastVixAlert) as? Date }
        set { defaults.set(newValue, forKey: Key.lastVixAlert) }
    }

    public func resetWeights() { weights = .default }

    private func doubleOr(_ key: String, _ fallback: Double) -> Double {
        defaults.object(forKey: key) as? Double ?? fallback
    }
}
