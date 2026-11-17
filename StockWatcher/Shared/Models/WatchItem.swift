import Foundation

/// An entry on the user's watchlist. Stored in the shared App Group so the
/// widget and the app read the exact same list.
public struct WatchItem: Identifiable, Equatable, Codable, Sendable {
    public var symbol: String        // Yahoo symbol, e.g. "RY.TO"
    public var name: String          // display name, e.g. "Royal Bank of Canada"

    public var id: String { symbol }

    public init(symbol: String, name: String) {
        self.symbol = symbol.uppercased()
        self.name = name
    }
}
