import Foundation

public struct PositionSizeResult: Sendable, Equatable {
    public let shares: Int
    public let dollarRisk: Double
    public let positionValue: Double
    public let rewardRisk: Double?
    public let note: String?
}

/// Risk-based position sizing (long/buy only). Shares = floor of the smallest of:
/// max-loss ÷ risk-per-share, position cap, and available cash.
/// Adapted (re-implemented in Swift) from the MIT day-trader-skill sizer.
public enum PositionSizer {
    public static func size(account: Double,
                            maxRiskUSD: Double,
                            entry: Double,
                            stop: Double,
                            target: Double? = nil,
                            maxPositionPct: Double = 0.75) -> PositionSizeResult {
        guard account > 0, entry > 0 else {
            return PositionSizeResult(shares: 0, dollarRisk: 0, positionValue: 0,
                                      rewardRisk: nil, note: "Enter account size and an entry price.")
        }
        let riskPerShare = entry - stop
        guard stop > 0, riskPerShare > 0 else {
            return PositionSizeResult(shares: 0, dollarRisk: 0, positionValue: 0,
                                      rewardRisk: nil, note: "Stop must be a price below the entry.")
        }
        let byRisk = maxRiskUSD / riskPerShare
        let byCap = account * maxPositionPct / entry
        let byCash = account / entry
        let shares = Int(Swift.min(byRisk, byCap, byCash).rounded(.down))
        let dollarRisk = Double(shares) * riskPerShare
        let positionValue = Double(shares) * entry
        let rr: Double? = target.map { ($0 - entry) / riskPerShare }
        let note = shares <= 0 ? "The stop is too far for your max risk — size would be 0." : nil
        return PositionSizeResult(shares: shares, dollarRisk: dollarRisk,
                                  positionValue: positionValue, rewardRisk: rr, note: note)
    }
}
