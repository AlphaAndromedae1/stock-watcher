import Foundation

/// Where an Altman Z″ score falls.
public enum AltmanZone: String, Equatable, Sendable {
    case safe
    case grey
    case distress

    public var title: String {
        switch self {
        case .safe: return "Safe zone"
        case .grey: return "Grey zone"
        case .distress: return "Distress zone"
        }
    }
}

public struct AltmanScore: Equatable, Sendable {
    public let z: Double
    public let zone: AltmanZone
    /// Working capital ÷ total assets.
    public let x1: Double
    /// Retained earnings ÷ total assets.
    public let x2: Double
    /// EBIT ÷ total assets, where EBIT is pre-tax income plus interest expense.
    public let x3: Double
    /// Book equity ÷ total liabilities.
    public let x4: Double
    public let ebit: Double
    /// |other income| ÷ |EBIT| for the latest year, when EBIT isn't zero.
    public let otherIncomeShare: Double?
    /// True when other income is a large share of EBIT, so EBIT includes non-operating items.
    public let flagged: Bool
    /// The fiscal year-end this score describes.
    public let latestYear: String

    public init(z: Double, zone: AltmanZone, x1: Double, x2: Double, x3: Double, x4: Double,
                ebit: Double, otherIncomeShare: Double?, flagged: Bool, latestYear: String) {
        self.z = z
        self.zone = zone
        self.x1 = x1
        self.x2 = x2
        self.x3 = x3
        self.x4 = x4
        self.ebit = ebit
        self.otherIncomeShare = otherIncomeShare
        self.flagged = flagged
        self.latestYear = latestYear
    }
}

/// Altman's Z″-score for non-manufacturers, in the version without the
/// emerging-market constant (the companies the app covers are developed-market
/// filers). Informational only and never part of the Stock Watcher Score.
public enum Altman {
    /// Other income at or above this share of EBIT flags the reading as distorted.
    public static let distortionThreshold = 0.2

    /// Scores the latest fiscal year (`years` newest first). Returns nil when pre-tax
    /// income or interest expense is missing for that year, since EBIT can't be built.
    public static func zScore(_ years: [AnnualYear]) -> AltmanScore? {
        guard let t = years.first else { return nil }
        guard let ca = t.values["annualCurrentAssets"],
              let cl = t.values["annualCurrentLiabilities"],
              let ta = t.values["annualTotalAssets"], ta > 0,
              let re = t.values["annualRetainedEarnings"],
              let equity = t.values["annualStockholdersEquity"],
              let liabilities = t.values["annualTotalLiabilitiesNetMinorityInterest"], liabilities > 0,
              let pretax = t.values["annualPretaxIncome"],
              let interest = t.values["annualInterestExpense"] else {
            return nil
        }

        let ebit = pretax + interest
        let x1 = (ca - cl) / ta
        let x2 = re / ta
        let x3 = ebit / ta
        let x4 = equity / liabilities
        let z = 6.56 * x1 + 3.26 * x2 + 6.72 * x3 + 1.05 * x4

        let zone: AltmanZone
        if z > 2.6 {
            zone = .safe
        } else if z < 1.1 {
            zone = .distress
        } else {
            zone = .grey
        }

        var share: Double? = nil
        if let other = t.values["annualOtherIncomeExpense"], ebit != 0 {
            share = abs(other) / abs(ebit)
        }
        let flagged = (share ?? 0) >= distortionThreshold

        return AltmanScore(z: z, zone: zone, x1: x1, x2: x2, x3: x3, x4: x4, ebit: ebit,
                           otherIncomeShare: share, flagged: flagged, latestYear: t.asOf)
    }
}
