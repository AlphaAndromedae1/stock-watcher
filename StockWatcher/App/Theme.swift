import SwiftUI

/// UI-side color mapping for ratings and signals, built from the shared PANTONE
/// palette (see Common/Pantone.swift) so the app matches the widget. Kept in the
/// app target so the Shared models stay free of SwiftUI.
extension Recommendation {
    var color: Color {
        switch self {
        case .strongBuy: return Pantone.emerald
        case .buy:       return Pantone.greenery
        case .neutral:   return Pantone.ultimateGray
        case .sell:      return Pantone.tangerine
        case .strongSell:return Pantone.flameScarlet
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
        case .buy:     return Pantone.emerald
        case .neutral: return Pantone.ultimateGray
        case .sell:    return Pantone.livingCoral
        }
    }
}

extension FundamentalAnalyzer.Verdict {
    var color: Color {
        switch self {
        case .good:    return Pantone.emerald
        case .fair:    return Pantone.illuminating
        case .weak:    return Pantone.livingCoral
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
        case .veryBullish: return Pantone.emerald
        case .bullish:     return Pantone.greenery
        case .mixed:       return Pantone.ultimateGray
        case .bearish:     return Pantone.tangerine
        case .veryBearish: return Pantone.flameScarlet
        }
    }
}

extension Flow {
    var color: Color {
        switch self {
        case .accumulating: return Pantone.emerald
        case .neutral:      return Pantone.ultimateGray
        case .distributing: return Pantone.livingCoral
        }
    }
    var systemImage: String {
        switch self {
        case .accumulating: return "arrow.up.circle.fill"
        case .neutral:      return "equal.circle.fill"
        case .distributing: return "arrow.down.circle.fill"
        }
    }
}

extension MarketMood.Band {
    var color: Color {
        switch self {
        case .calm:    return Pantone.emerald
        case .normal:  return Pantone.greenery
        case .guarded: return Pantone.illuminating
        case .fearful: return Pantone.tangerine
        case .panic:   return Pantone.flameScarlet
        }
    }
}

extension NewsTone.Label {
    var color: Color {
        switch self {
        case .positive: return Pantone.emerald
        case .mixed:    return Pantone.ultimateGray
        case .negative: return Pantone.livingCoral
        }
    }
}

extension ChartSignal.Bias {
    var color: Color {
        switch self {
        case .bullish: return Pantone.emerald
        case .bearish: return Pantone.livingCoral
        case .neutral: return Pantone.ultimateGray
        }
    }
}

extension Color {
    static func forChange(_ up: Bool) -> Color { up ? Pantone.emerald : Pantone.livingCoral }
}
