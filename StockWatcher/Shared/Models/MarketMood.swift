import Foundation

/// A read on broad market fear using volatility indexes. VIX is the S&P 500's
/// 30-day implied volatility (the global "fear gauge"); VIXC is its S&P/TSX 60
/// equivalent. Either can be missing, so everything is optional.
public struct MarketMood: Sendable, Equatable, Codable {
    public let vix: Double?
    public let vixChangePercent: Double?
    public let vixc: Double?
    public let asOf: Date

    public init(vix: Double?, vixChangePercent: Double?, vixc: Double?, asOf: Date) {
        self.vix = vix
        self.vixChangePercent = vixChangePercent
        self.vixc = vixc
        self.asOf = asOf
    }

    public enum Band: Int, Sendable, Codable, CaseIterable {
        case calm, normal, guarded, fearful, panic

        public var label: String {
            switch self {
            case .calm: return "Calm"
            case .normal: return "Normal"
            case .guarded: return "Guarded"
            case .fearful: return "Fearful"
            case .panic: return "Panic"
            }
        }

        public var guidance: String {
            switch self {
            case .calm: return "Low volatility — markets are relaxed, even complacent."
            case .normal: return "Typical volatility. No broad stress signal."
            case .guarded: return "Volatility is picking up — some caution creeping in."
            case .fearful: return "Elevated fear. Expect bigger swings and selling pressure."
            case .panic: return "Extreme fear — historically near capitulation; contrarians watch here."
            }
        }
    }

    /// Prefer VIX as the headline; fall back to VIXC if VIX is unavailable.
    public var headline: Double? { vix ?? vixc }
    public var headlineName: String { vix != nil ? "VIX" : "VIXC" }
    public var band: Band? { headline.map(Self.band(for:)) }

    public static func band(for value: Double) -> Band {
        switch value {
        case ..<15: return .calm
        case 15..<20: return .normal
        case 20..<28: return .guarded
        case 28..<38: return .fearful
        default: return .panic
        }
    }
}
