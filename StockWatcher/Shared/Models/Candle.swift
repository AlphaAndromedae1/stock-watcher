import Foundation

/// A single OHLCV price bar.
public struct Candle: Identifiable, Equatable, Codable, Sendable {
    public let date: Date
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Double

    public var id: TimeInterval { date.timeIntervalSince1970 }

    public init(date: Date, open: Double, high: Double, low: Double, close: Double, volume: Double) {
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }
}

public extension Array where Element == Candle {
    var closes: [Double] { map(\.close) }
    var highs: [Double] { map(\.high) }
    var lows: [Double] { map(\.low) }
    var opens: [Double] { map(\.open) }
    var volumes: [Double] { map(\.volume) }
}
