import Foundation

public struct ScoreSample: Codable, Equatable, Sendable, Identifiable {
    public let date: Date
    public let score: Int
    public var id: TimeInterval { date.timeIntervalSince1970 }

    public init(date: Date, score: Int) {
        self.date = date
        self.score = score
    }
}

/// Persists the Stock Watcher Score over time per symbol (App Group), so the
/// detail screen can show how the signal is trending. At most one sample per
/// day per symbol; capped history.
public final class ScoreHistoryStore: @unchecked Sendable {
    public static let shared = ScoreHistoryStore()

    private let defaults: UserDefaults
    private let maxSamples = 90

    public init() {
        defaults = UserDefaults(suiteName: WatchlistStore.appGroupID) ?? .standard
    }

    private func key(_ symbol: String) -> String { "scoreHistory.\(symbol.uppercased())" }

    public func history(symbol: String) -> [ScoreSample] {
        guard let data = defaults.data(forKey: key(symbol)),
              let samples = try? JSONDecoder().decode([ScoreSample].self, from: data) else { return [] }
        return samples
    }

    public func record(symbol: String, score: Int, now: Date = Date()) {
        var samples = history(symbol: symbol)
        if let last = samples.last,
           Calendar.current.isDate(last.date, inSameDayAs: now) {
            // Replace today's sample with the latest reading.
            samples[samples.count - 1] = ScoreSample(date: now, score: score)
        } else {
            samples.append(ScoreSample(date: now, score: score))
        }
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
        if let data = try? JSONEncoder().encode(samples) {
            defaults.set(data, forKey: key(symbol))
        }
    }
}
