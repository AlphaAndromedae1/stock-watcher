import Foundation

/// A tiny Codable disk cache in the App Group container so screens can show the
/// last-known data instantly (and offline) while fresh data loads. Best-effort:
/// every read/write is wrapped and failures are swallowed.
public final class DataCache: @unchecked Sendable {
    public static let shared = DataCache()

    private let directory: URL?
    private let fallback: URL

    public init() {
        let fm = FileManager.default
        directory = fm.containerURL(forSecurityApplicationGroupIdentifier: WatchlistStore.appGroupID)?
            .appendingPathComponent("cache", isDirectory: true)
        fallback = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("stockwatcher-cache", isDirectory: true)
        try? fm.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    private var baseURL: URL { directory ?? fallback }

    /// True when the App Group container is available — i.e. the app and widget
    /// actually share storage. False on sideloaded builds where the group wasn't
    /// provisioned (the widget then falls back to the default list).
    public var appGroupAvailable: Bool { directory != nil }

    private func url(_ key: String) -> URL {
        let safe = key.replacingOccurrences(of: "^", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".", with: "_")
        return baseURL.appendingPathComponent("\(safe).json")
    }

    public func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url(key), options: .atomic)
    }

    public func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = try? Data(contentsOf: url(key)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Age of a cache entry, or nil if missing.
    public func age(key: String) -> TimeInterval? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url(key).path),
              let modified = attrs[.modificationDate] as? Date else { return nil }
        return Date().timeIntervalSince(modified)
    }

    public func clearAll() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil) else { return }
        for item in items { try? fm.removeItem(at: item) }
    }

    /// Deletes entries not written in the last `age` seconds, so the cache can't grow
    /// without limit. Returns how many were removed.
    @discardableResult
    public func purge(olderThan age: TimeInterval) -> Int {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil) else {
            return 0
        }
        let cutoff = Date().addingTimeInterval(-age)
        var removed = 0
        for item in items {
            guard let values = try? item.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate,
                  modified < cutoff else { continue }
            if (try? fm.removeItem(at: item)) != nil {
                removed += 1
            }
        }
        return removed
    }

    public func fileCount() -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: baseURL.path).count) ?? 0
    }

    public var locationDescription: String {
        directory != nil ? "App Group container" : "Local caches (App Group unavailable)"
    }
}
