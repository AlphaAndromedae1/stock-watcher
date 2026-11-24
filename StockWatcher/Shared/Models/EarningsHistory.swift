import Foundation

/// Recent quarterly earnings — revenue, net income, and EPS actual vs. estimate.
/// Best-effort from Yahoo's `earnings` module; every field optional.
/// Quarters are ordered oldest → newest.
public struct EarningsHistory: Equatable, Sendable, Codable {
    public struct Quarter: Equatable, Sendable, Codable, Identifiable {
        public let label: String        // "1Q2024"
        public let revenue: Double?
        public let earnings: Double?     // net income
        public let epsActual: Double?
        public let epsEstimate: Double?
        public var id: String { label }

        public init(label: String, revenue: Double?, earnings: Double?,
                    epsActual: Double?, epsEstimate: Double?) {
            self.label = label
            self.revenue = revenue
            self.earnings = earnings
            self.epsActual = epsActual
            self.epsEstimate = epsEstimate
        }

        /// Did reported EPS meet or beat the estimate? nil if either is missing.
        public var beatEstimate: Bool? {
            guard let a = epsActual, let e = epsEstimate else { return nil }
            return a >= e
        }
    }

    public var quarters: [Quarter]

    public init() { quarters = [] }

    public var isEmpty: Bool { quarters.isEmpty }

    /// Change in revenue from the first to the last available quarter in the
    /// window (≈ year-over-year when four quarters are present), as a fraction.
    public var revenueTrend: Double? { trend(\.revenue) }

    /// Same, for net income.
    public var earningsTrend: Double? { trend(\.earnings) }

    private func trend(_ key: KeyPath<Quarter, Double?>) -> Double? {
        let vals = quarters.compactMap { $0[keyPath: key] }
        guard let first = vals.first, let last = vals.last, first != 0 else { return nil }
        return (last - first) / abs(first)
    }
}
