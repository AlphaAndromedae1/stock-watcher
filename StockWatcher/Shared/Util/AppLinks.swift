import Foundation

/// Deep-link URL scheme shared by the app (handling) and widgets (building).
/// Example: stockwatcher://stock?symbol=XEQT.TO
public enum StockWatcherURL {
    public static let scheme = "stockwatcher"

    public static func stock(_ symbol: String) -> URL? {
        var c = URLComponents()
        c.scheme = scheme
        c.host = "stock"
        c.queryItems = [URLQueryItem(name: "symbol", value: symbol)]
        return c.url
    }

    public static func symbol(from url: URL) -> String? {
        guard url.scheme == scheme else { return nil }
        let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "symbol" })?.value
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

/// TSX regular trading hours: 9:30–16:00 America/Toronto, Mon–Fri.
/// (Does not account for market holidays.)
public enum MarketHours {
    public static func isTSXOpen(at date: Date = Date()) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        guard let tz = TimeZone(identifier: "America/Toronto") else { return false }
        cal.timeZone = tz
        let comps = cal.dateComponents([.weekday, .hour, .minute], from: date)
        guard let wd = comps.weekday, let h = comps.hour, let m = comps.minute else { return false }
        if wd == 1 || wd == 7 { return false }   // Sunday = 1, Saturday = 7
        let minutes = h * 60 + m
        return minutes >= (9 * 60 + 30) && minutes < (16 * 60)
    }
}
