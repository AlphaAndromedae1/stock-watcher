import Foundation

public enum Fmt {
    public static func price(_ v: Double?, currency: String? = nil) -> String {
        guard let v, v.isFinite else { return "—" }
        let s = String(format: "%.2f", v)
        if let c = currency, !c.isEmpty { return "\(s) \(c)" }
        return s
    }

    public static func signedPercent(_ v: Double?) -> String {
        guard let v, v.isFinite else { return "—" }
        return String(format: "%+.2f%%", v)
    }

    public static func signed(_ v: Double?) -> String {
        guard let v, v.isFinite else { return "—" }
        return String(format: "%+.2f", v)
    }

    public static func number(_ v: Double?, decimals: Int = 2) -> String {
        guard let v, v.isFinite else { return "—" }
        return String(format: "%.\(decimals)f", v)
    }

    /// Fraction (0.042) -> "4.2%".
    public static func percentFromFraction(_ v: Double?, decimals: Int = 1) -> String {
        guard let v, v.isFinite else { return "—" }
        return String(format: "%.\(decimals)f%%", v * 100)
    }

    /// Large currency figures: 1_250_000_000 -> "1.25B".
    public static func bigNumber(_ v: Double?) -> String {
        guard let v, v.isFinite else { return "—" }
        let a = abs(v)
        let sign = v < 0 ? "-" : ""
        switch a {
        case 1e12...: return String(format: "%@%.2fT", sign, a / 1e12)
        case 1e9...:  return String(format: "%@%.2fB", sign, a / 1e9)
        case 1e6...:  return String(format: "%@%.2fM", sign, a / 1e6)
        case 1e3...:  return String(format: "%@%.2fK", sign, a / 1e3)
        default:      return String(format: "%@%.0f", sign, a)
        }
    }

    public static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}
