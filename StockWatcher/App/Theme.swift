import SwiftUI

/// UI-side color mapping for ratings and signals. Kept in the app target so the
/// Shared models stay free of SwiftUI.
extension Recommendation {
    var color: Color {
        switch self {
        case .strongBuy: return Color(red: 0.11, green: 0.70, blue: 0.42)
        case .buy:       return Color(red: 0.30, green: 0.78, blue: 0.47)
        case .neutral:   return Color(red: 0.55, green: 0.57, blue: 0.62)
        case .sell:      return Color(red: 0.93, green: 0.49, blue: 0.33)
        case .strongSell:return Color(red: 0.90, green: 0.26, blue: 0.29)
        }
    }

    var systemImage: String {
        switch self {
        case .strongBuy: return "arrow.up.forward.circle.fill"
        case .buy:       return "arrow.up.right.circle.fill"
        case .neutral:   return "equal.circle.fill"
        case .sell:      return "arrow.down.right.circle.fill"
        case .strongSell:return "arrow.down.forward.circle.fill"
        }
    }
}

extension Signal {
    var color: Color {
        switch self {
        case .buy:     return Color(red: 0.20, green: 0.72, blue: 0.45)
        case .neutral: return Color(red: 0.55, green: 0.57, blue: 0.62)
        case .sell:    return Color(red: 0.90, green: 0.30, blue: 0.33)
        }
    }
}

extension FundamentalAnalyzer.Verdict {
    var color: Color {
        switch self {
        case .good:    return Color(red: 0.20, green: 0.72, blue: 0.45)
        case .fair:    return Color(red: 0.92, green: 0.70, blue: 0.25)
        case .weak:    return Color(red: 0.90, green: 0.30, blue: 0.33)
        case .unknown: return .secondary
        }
    }

    var systemImage: String {
        switch self {
        case .good:    return "checkmark.circle.fill"
        case .fair:    return "minus.circle.fill"
        case .weak:    return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

extension CompositeEvaluator.Band {
    var color: Color {
        switch self {
        case .veryBullish: return Color(red: 0.11, green: 0.70, blue: 0.42)
        case .bullish:     return Color(red: 0.30, green: 0.78, blue: 0.47)
        case .mixed:       return Color(red: 0.55, green: 0.57, blue: 0.62)
        case .bearish:     return Color(red: 0.93, green: 0.49, blue: 0.33)
        case .veryBearish: return Color(red: 0.90, green: 0.26, blue: 0.29)
        }
    }
}

extension MarketMood.Band {
    var color: Color {
        switch self {
        case .calm:    return Color(red: 0.20, green: 0.72, blue: 0.45)
        case .normal:  return Color(red: 0.36, green: 0.73, blue: 0.55)
        case .guarded: return Color(red: 0.92, green: 0.70, blue: 0.25)
        case .fearful: return Color(red: 0.93, green: 0.49, blue: 0.33)
        case .panic:   return Color(red: 0.90, green: 0.26, blue: 0.29)
        }
    }
}

extension Color {
    static func forChange(_ up: Bool) -> Color {
        up ? Color(red: 0.20, green: 0.72, blue: 0.45) : Color(red: 0.90, green: 0.30, blue: 0.33)
    }
}
