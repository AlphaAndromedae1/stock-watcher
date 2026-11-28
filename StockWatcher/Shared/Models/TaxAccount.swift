import Foundation

/// The account a holding sits in. Drives the tax notes on each stock's Quant
/// Checks card (e.g. U.S. dividend withholding). Pure data, no SwiftUI.
public enum TaxAccount: String, CaseIterable, Sendable {
    case tfsa
    case rrsp
    case nonRegistered

    public var title: String {
        switch self {
        case .tfsa: return "TFSA"
        case .rrsp: return "RRSP / RRIF"
        case .nonRegistered: return "Non-registered"
        }
    }
}
