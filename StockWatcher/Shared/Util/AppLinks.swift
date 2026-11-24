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

    /// Next time the widget timeline should refresh, confined to weekdays
    /// 9:30 AM – 4:30 PM America/Toronto. Outside that window the next refresh
    /// is parked at the following session's open, so WidgetKit isn't woken
    /// (and Yahoo isn't polled) overnight or on weekends when prices can't move.
    public static func nextWidgetRefresh(after date: Date = Date(),
                                         intervalMinutes: Int = 30) -> Date {
        var cal = Calendar(identifier: .gregorian)
        guard let tz = TimeZone(identifier: "America/Toronto") else {
            return date.addingTimeInterval(Double(intervalMinutes) * 60)
        }
        cal.timeZone = tz
        let openMin = 9 * 60 + 30
        let closeMin = 16 * 60 + 30   // keep refreshing 30 min past the close

        func isWeekday(_ d: Date) -> Bool {
            let wd = cal.component(.weekday, from: d)
            return wd != 1 && wd != 7
        }
        func minutesOfDay(_ d: Date) -> Int {
            let c = cal.dateComponents([.hour, .minute], from: d)
            return (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
        func atOpen(_ d: Date) -> Date {
            cal.date(bySettingHour: 9, minute: 30, second: 0, of: d) ?? d
        }

        // A normal interval step from now.
        let candidate = date.addingTimeInterval(Double(intervalMinutes) * 60)

        if isWeekday(candidate) {
            let m = minutesOfDay(candidate)
            if m >= openMin && m <= closeMin { return candidate }  // in session
            if m < openMin { return atOpen(candidate) }            // pre-market → open
        }

        // After hours or weekend → roll to the next weekday's open.
        var day = candidate
        repeat {
            day = cal.date(byAdding: .day, value: 1, to: day) ?? day
        } while !isWeekday(day)
        return atOpen(day)
    }
}
