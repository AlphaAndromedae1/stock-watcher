import Foundation

public enum YahooError: Error, LocalizedError {
    case badURL
    case http(Int)
    case empty
    case noData

    public var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid request."
        case .http(let code): return "Server returned HTTP \(code)."
        case .empty: return "No data returned for that symbol."
        case .noData: return "No price history available."
        }
    }
}

public enum ChartRange: String, CaseIterable, Sendable {
    case oneDay = "1d"
    case fiveDay = "5d"
    case oneMonth = "1mo"
    case sixMonth = "6mo"
    case oneYear = "1y"
    case fiveYear = "5y"

    public var interval: String {
        switch self {
        case .oneDay: return "5m"
        case .fiveDay: return "30m"
        case .oneMonth: return "1d"
        case .sixMonth: return "1d"
        case .oneYear: return "1d"
        case .fiveYear: return "1wk"
        }
    }

    public var label: String {
        switch self {
        case .oneDay: return "1D"
        case .fiveDay: return "5D"
        case .oneMonth: return "1M"
        case .sixMonth: return "6M"
        case .oneYear: return "1Y"
        case .fiveYear: return "5Y"
        }
    }
}

/// Talks to Yahoo Finance's public endpoints. No API key required.
///
/// - The chart endpoint (prices/history) is stable and is the backbone of the
///   app and widget.
/// - The quoteSummary endpoint (fundamentals) is crumb/cookie gated and
///   occasionally rate-limited, so it is strictly best-effort: failures return
///   empty `Fundamentals` rather than throwing.
public final class YahooService: @unchecked Sendable {
    public static let shared = YahooService()

    private let session: URLSession
    private let crumbs = CrumbProvider()

    public init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
    }

    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " +
        "(KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    private func makeRequest(_ url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }

    // MARK: - Chart / history

    public func fetchCandles(symbol: String, range: ChartRange) async throws -> (candles: [Candle], meta: ChartResponse.Meta) {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        guard let url = URL(string:
            "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?range=\(range.rawValue)&interval=\(range.interval)&includePrePost=false")
        else { throw YahooError.badURL }

        let (data, response) = try await session.data(for: makeRequest(url))
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw YahooError.http(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChartResponse.self, from: data)
        guard let result = decoded.chart.result?.first else { throw YahooError.empty }

        let candles = Self.candles(from: result)
        return (candles, result.meta)
    }

    /// A lightweight live quote. Uses a tiny chart request so it works without a
    /// crumb — ideal for the widget and list rows.
    public func fetchQuote(symbol: String) async throws -> Quote {
        let (_, meta) = try await fetchCandles(symbol: symbol, range: .fiveDay)
        return Self.quote(from: meta, fallbackSymbol: symbol)
    }

    public func fetchQuotes(symbols: [String]) async -> [Quote] {
        await withTaskGroup(of: Quote?.self) { group in
            for s in symbols {
                group.addTask { try? await self.fetchQuote(symbol: s) }
            }
            var out: [Quote] = []
            for await q in group { if let q { out.append(q) } }
            // Preserve the caller's ordering.
            return symbols.compactMap { sym in out.first { $0.symbol == sym } }
        }
    }

    // MARK: - Fundamentals (best effort)

    public func fetchFundamentals(symbol: String) async -> Fundamentals {
        do {
            return try await requestFundamentals(symbol: symbol, retryOnAuth: true)
        } catch {
            return Fundamentals()  // graceful: UI hides the section
        }
    }

    private func requestFundamentals(symbol: String, retryOnAuth: Bool) async throws -> Fundamentals {
        let crumb = try await crumbs.crumb(session: session, userAgent: Self.userAgent)
        let modules = "summaryDetail,defaultKeyStatistics,financialData,calendarEvents"
        let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        let encodedCrumb = crumb.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? crumb
        guard let url = URL(string:
            "https://query2.finance.yahoo.com/v10/finance/quoteSummary/\(encodedSymbol)?modules=\(modules)&crumb=\(encodedCrumb)")
        else { throw YahooError.badURL }

        let (data, response) = try await session.data(for: makeRequest(url))
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 && retryOnAuth {
                await crumbs.invalidate()
                return try await requestFundamentals(symbol: symbol, retryOnAuth: false)
            }
            if !(200...299).contains(http.statusCode) { throw YahooError.http(http.statusCode) }
        }

        let decoded = try JSONDecoder().decode(QuoteSummaryResponse.self, from: data)
        guard let r = decoded.quoteSummary?.result?.first else { throw YahooError.empty }
        return Self.fundamentals(from: r)
    }

    // MARK: - Mapping

    static func candles(from result: ChartResponse.Result) -> [Candle] {
        guard let ts = result.timestamp,
              let q = result.indicators.quote?.first else { return [] }
        let opens = q.open ?? []
        let highs = q.high ?? []
        let lows = q.low ?? []
        let closes = q.close ?? []
        let vols = q.volume ?? []

        func at(_ array: [Double?], _ i: Int) -> Double? {
            array.indices.contains(i) ? array[i] : nil
        }

        var out: [Candle] = []
        out.reserveCapacity(ts.count)
        for i in ts.indices {
            guard let o = at(opens, i), let h = at(highs, i),
                  let l = at(lows, i), let c = at(closes, i) else { continue }
            let v = at(vols, i) ?? 0
            out.append(Candle(date: Date(timeIntervalSince1970: ts[i]),
                              open: o, high: h, low: l, close: c, volume: v))
        }
        return out
    }

    static func quote(from meta: ChartResponse.Meta, fallbackSymbol: String) -> Quote {
        let price = meta.regularMarketPrice ?? meta.chartPreviousClose ?? 0
        let prev = meta.chartPreviousClose ?? meta.previousClose ?? price
        let name = meta.shortName ?? meta.longName ?? TSXCatalog.name(for: fallbackSymbol)
        let time = meta.regularMarketTime.map { Date(timeIntervalSince1970: $0) } ?? Date()
        return Quote(symbol: meta.symbol ?? fallbackSymbol,
                     shortName: name,
                     currency: meta.currency,
                     price: price,
                     previousClose: prev,
                     exchange: meta.exchangeName,
                     asOf: time)
    }

    static func fundamentals(from r: QuoteSummaryResponse.Result) -> Fundamentals {
        var f = Fundamentals()
        f.marketCap = r.summaryDetail?.marketCap?.raw
        f.trailingPE = r.summaryDetail?.trailingPE?.raw
        f.forwardPE = r.summaryDetail?.forwardPE?.raw ?? r.defaultKeyStatistics?.forwardPE?.raw
        f.dividendYield = r.summaryDetail?.dividendYield?.raw
        f.beta = r.summaryDetail?.beta?.raw ?? r.defaultKeyStatistics?.beta?.raw
        f.fiftyTwoWeekHigh = r.summaryDetail?.fiftyTwoWeekHigh?.raw
        f.fiftyTwoWeekLow = r.summaryDetail?.fiftyTwoWeekLow?.raw
        f.priceToBook = r.defaultKeyStatistics?.priceToBook?.raw
        f.pegRatio = r.defaultKeyStatistics?.pegRatio?.raw
        f.profitMargin = r.financialData?.profitMargins?.raw
        f.returnOnEquity = r.financialData?.returnOnEquity?.raw
        f.debtToEquity = r.financialData?.debtToEquity?.raw
        f.revenueGrowth = r.financialData?.revenueGrowth?.raw
        f.earningsGrowth = r.financialData?.earningsGrowth?.raw
        f.recommendationKey = r.financialData?.recommendationKey
        f.numberOfAnalysts = r.financialData?.numberOfAnalystOpinions?.raw.map { Int($0) }
        f.targetMeanPrice = r.financialData?.targetMeanPrice?.raw
        f.dividendRate = r.summaryDetail?.dividendRate?.raw

        func date(_ epoch: Double?) -> Date? {
            guard let epoch, epoch > 0 else { return nil }
            return Date(timeIntervalSince1970: epoch)
        }
        f.exDividendDate = date(r.summaryDetail?.exDividendDate?.raw ?? r.calendarEvents?.exDividendDate?.raw)
        f.nextEarningsDate = date(r.calendarEvents?.earnings?.earningsDate?.first?.raw)
        return f
    }
}

/// Serializes crumb retrieval so concurrent requests share one cookie/crumb.
actor CrumbProvider {
    private var cached: String?

    func invalidate() { cached = nil }

    func crumb(session: URLSession, userAgent: String) async throws -> String {
        if let cached { return cached }

        // 1) Prime cookies by hitting the consent/finance host.
        if let home = URL(string: "https://fc.yahoo.com/") {
            var req = URLRequest(url: home)
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            _ = try? await session.data(for: req)
        }

        // 2) Ask for the crumb (needs the cookie set above).
        guard let url = URL(string: "https://query2.finance.yahoo.com/v1/test/getcrumb") else {
            throw YahooError.badURL
        }
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("*/*", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw YahooError.http(http.statusCode)
        }
        guard let value = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty, !value.contains("<") else {
            throw YahooError.noData
        }
        cached = value
        return value
    }
}
