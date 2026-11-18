import Foundation
import UserNotifications

/// Requests notification permission, and checks alerts against fresh data to
/// fire local notifications. Runs from the app and from background refresh.
final class NotificationManager: @unchecked Sendable {
    static let shared = NotificationManager()

    private let debounce: TimeInterval = 6 * 3600   // don't repeat an alert within 6h

    @discardableResult
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        return granted
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// The core check. Safe to call often; it self-debounces.
    func checkAndNotify() async {
        guard SettingsStore.shared.alertsEnabled else { return }
        let store = AlertStore.shared
        let active = store.all().filter { $0.enabled }

        let symbols = Set(active.map { $0.symbol })
        for symbol in symbols {
            guard let result = try? await YahooService.shared.fetchCandles(symbol: symbol, range: .oneYear),
                  !result.candles.isEmpty else { continue }
            let quote = YahooService.quote(from: result.meta, fallbackSymbol: symbol)
            let recommendation = TechnicalAnalyzer.analyze(result.candles).summary

            for var alert in active where alert.symbol == symbol {
                guard let message = evaluate(alert, price: quote.price, rec: recommendation) else { continue }
                if let last = alert.lastTriggered, Date().timeIntervalSince(last) < debounce { continue }
                await fire(title: "\(alert.symbolDisplay) alert", body: message)
                alert.lastTriggered = Date()
                store.update(alert)
            }
        }

        await checkVIX()
    }

    private func evaluate(_ alert: PriceAlert, price: Double, rec: Recommendation) -> String? {
        switch alert.kind {
        case .priceAbove:
            return price >= alert.threshold ? "\(alert.symbolDisplay) is \(Fmt.price(price)) — at or above your \(Fmt.price(alert.threshold)) alert." : nil
        case .priceBelow:
            return price <= alert.threshold ? "\(alert.symbolDisplay) is \(Fmt.price(price)) — at or below your \(Fmt.price(alert.threshold)) alert." : nil
        case .ratingBuy:
            return (rec == .buy || rec == .strongBuy) ? "\(alert.symbolDisplay) technical rating is now \(rec.label)." : nil
        case .ratingSell:
            return (rec == .sell || rec == .strongSell) ? "\(alert.symbolDisplay) technical rating is now \(rec.label)." : nil
        }
    }

    private func checkVIX() async {
        guard SettingsStore.shared.vixAlertEnabled else { return }
        guard let vix = try? await YahooService.shared.fetchQuote(symbol: "^VIX") else { return }
        let band = MarketMood.band(for: vix.price)
        guard band == .fearful || band == .panic else { return }
        if let last = SettingsStore.shared.lastVixAlert,
           Date().timeIntervalSince(last) < 24 * 3600 { return }
        await fire(title: "Market fear rising",
                   body: "VIX is \(Fmt.number(vix.price, decimals: 1)) — market mood is \(band.label).")
        SettingsStore.shared.lastVixAlert = Date()
    }

    private func fire(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
