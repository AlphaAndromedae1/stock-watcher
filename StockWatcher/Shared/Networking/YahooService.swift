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

/// Result of probing whether Yahoo returns annual statement history for a symbol.
/// Debug-only: it tells us whether Tier-2 metrics (Piotroski, Altman, Magic Formula)
/// are feasible from this data source. Never used in a score.
public struct StatementProbeResult: Sendable {
    public struct Field: Sendable {
        public let name: String
        /// Annual values that carry a reported number.
        public let years: Int
        /// The most recent `asOfDate` returned, e.g. "2025-10-31".
        public let latest: String?
        /// The most recent reported value in the filing's currency (raw, not scaled).
        public let latestValue: Double?
        /// The filing's reporting currency, e.g. "CAD" or "USD".
        public let currency: String?
        /// Every reported annual value, newest first.
        public let series: [Point]

        public init(name: String, years: Int, latest: String?,
                    latestValue: Double? = nil, currency: String? = nil,
                    series: [Point] = []) {
            self.name = name
            self.years = years
            self.latest = latest
            self.latestValue = latestValue
            self.currency = currency
            self.series = series
        }
    }

    /// One reported annual value (the same type the Piotroski series uses).
    public typealias Point = AnnualPoint

    public let symbol: String
    /// Which request produced this result: "no crumb" or "with crumb".
    public let path: String
    public let httpStatus: Int?
    public let fields: [Field]
    /// Error text or a short body excerpt when the request did not succeed.
    public let note: String?

    public init(symbol: String, path: String, httpStatus: Int?, fields: [Field], note: String?) {
        self.symbol = symbol
        self.path = path
        self.httpStatus = httpStatus
        self.fields = fields
        self.note = note
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

    // MARK: - Symbol search / autocomplete (best effort)

    /// Live symbol lookup for any ticker or company keyword, across exchanges
    /// (keyless). Best-effort: returns [] on failure so the UI falls back to the
    /// offline TSX catalog. Results are mapped into `TSXCatalog.Entry` with the
    /// exchange name in `sector`.
    public func searchSymbols(query: String) async -> [TSXCatalog.Entry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 1 else { return [] }
        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        guard let url = URL(string:
            "https://query1.finance.yahoo.com/v1/finance/search?q=\(encoded)&quotesCount=12&newsCount=0&listsCount=0&enableFuzzyQuery=false")
        else { return [] }
        do {
            let (data, response) = try await session.data(for: makeRequest(url))
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return [] }
            let decoded = try JSONDecoder().decode(YahooSearchResponse.self, from: data)
            return (decoded.quotes ?? []).compactMap { h in
                guard let sym = h.symbol, !sym.isEmpty else { return nil }
                // Skip quote types that aren't tradeable symbols (options, etc.).
                let type = (h.quoteType ?? "").uppercased()
                guard type != "OPTION" else { return nil }
                let name = h.longname ?? h.shortname ?? sym
                return TSXCatalog.Entry(symbol: sym, name: name, sector: h.exchDisp ?? type)
            }
        } catch {
            return []
        }
    }

    // MARK: - Annual statement probe (debug only, Tier-2 data check)

    /// Annual statement types the Tier-2 metrics would need.
    static let statementTypes: [String] = [
        "annualTotalRevenue", "annualGrossProfit", "annualEBIT", "annualNetIncome",
        "annualOperatingCashFlow", "annualTotalAssets", "annualTotalLiabilitiesNetMinorityInterest",
        "annualCurrentAssets", "annualCurrentLiabilities", "annualRetainedEarnings",
        "annualLongTermDebt", "annualStockholdersEquity", "annualDilutedAverageShares",
        "annualRepurchaseOfCapitalStock", "annualCashDividendsPaid",
        // Needed for Magic Formula (enterprise value and invested capital).
        "annualCashAndCashEquivalents", "annualCashCashEquivalentsAndShortTermInvestments",
        "annualNetPPE",
        // EBIT cross-check: which definition Yahoo's EBIT actually follows.
        "annualOperatingIncome", "annualPretaxIncome", "annualInterestExpense",
        "annualOtherIncomeExpense", "annualEBITDA",
        // Debt including the current portion: tests whether a missing long-term debt
        // line is a reclassification to current rather than a true zero.
        "annualTotalDebt", "annualCurrentDebtAndCapitalLeaseObligation",
        // Cash-flow and working-capital cross-checks.
        "annualCapitalExpenditure", "annualFreeCashFlow", "annualWorkingCapital"
    ]

    /// Asks the fundamentals-timeseries endpoint for annual statement history.
    /// Tries without a crumb first, and adds the crumb only if Yahoo refuses.
    public func probeAnnualStatements(symbol: String) async -> StatementProbeResult {
        let types = Self.statementTypes.joined(separator: ",")
        let now = Int(Date().timeIntervalSince1970)
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        let base = "https://query2.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/timeseries/\(encoded)?type=\(types)&period1=1262304000&period2=\(now)"

        let first = await runStatementRequest(urlString: base, symbol: symbol, path: "no crumb")
        guard first.httpStatus == 401 || first.httpStatus == 403 else { return first }

        guard let crumb = try? await crumbs.crumb(session: session, userAgent: Self.userAgent) else {
            return StatementProbeResult(symbol: symbol, path: "with crumb", httpStatus: nil,
                                        fields: [], note: "could not obtain a crumb")
        }
        let encodedCrumb = crumb.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? crumb
        return await runStatementRequest(urlString: base + "&crumb=\(encodedCrumb)",
                                         symbol: symbol, path: "with crumb")
    }

    private func runStatementRequest(urlString: String, symbol: String, path: String) async -> StatementProbeResult {
        guard let url = URL(string: urlString) else {
            return StatementProbeResult(symbol: symbol, path: path, httpStatus: nil,
                                        fields: [], note: "bad URL")
        }
        do {
            let (data, response) = try await session.data(for: makeRequest(url))
            let status = (response as? HTTPURLResponse)?.statusCode
            guard let status, (200...299).contains(status) else {
                let excerpt = String(data: data.prefix(120), encoding: .utf8) ?? "non-text body"
                return StatementProbeResult(symbol: symbol, path: path, httpStatus: status,
                                            fields: [], note: excerpt)
            }
            return Self.parseStatements(data, symbol: symbol, path: path, status: status)
        } catch {
            return StatementProbeResult(symbol: symbol, path: path, httpStatus: nil,
                                        fields: [], note: error.localizedDescription)
        }
    }

    /// Parses the timeseries JSON without a strict Codable model, so a shape
    /// mismatch is reported as such instead of being misread as "no data".
    static func parseStatements(_ data: Data, symbol: String, path: String, status: Int) -> StatementProbeResult {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let ts = root["timeseries"] as? [String: Any] else {
            return StatementProbeResult(symbol: symbol, path: path, httpStatus: status,
                                        fields: [], note: "unexpected response shape")
        }
        if let err = ts["error"] as? [String: Any], let desc = err["description"] as? String {
            return StatementProbeResult(symbol: symbol, path: path, httpStatus: status,
                                        fields: [], note: "Yahoo error: \(desc)")
        }

        // Each result element holds one array per requested type, keyed by the type name.
        let results = ts["result"] as? [[String: Any]] ?? []
        var rowsByType: [String: [[String: Any]]] = [:]
        for result in results {
            for (key, value) in result where key.hasPrefix("annual") {
                if let rows = value as? [[String: Any]] {
                    rowsByType[key] = rows
                }
            }
        }

        var fields: [StatementProbeResult.Field] = []
        for type in statementTypes {
            guard let rows = rowsByType[type] else {
                fields.append(StatementProbeResult.Field(name: type, years: 0, latest: nil))
                continue
            }
            let reported = rows.filter { row in
                (row["reportedValue"] as? [String: Any])?["raw"] != nil
            }
            // The newest row by as-of date carries the latest reported value.
            let newest = reported.max { a, b in
                ((a["asOfDate"] as? String) ?? "") < ((b["asOfDate"] as? String) ?? "")
            }
            let latestDate = newest?["asOfDate"] as? String
            let latestReported = newest?["reportedValue"] as? [String: Any]
            let latestRaw = latestReported?["raw"] as? Double
            let currency = newest?["currencyCode"] as? String
            let series: [StatementProbeResult.Point] = reported.compactMap { (row: [String: Any]) -> StatementProbeResult.Point? in
                guard let date = row["asOfDate"] as? String,
                      let raw = (row["reportedValue"] as? [String: Any])?["raw"] as? Double else { return nil }
                return StatementProbeResult.Point(asOfDate: date, value: raw)
            }.sorted { $0.asOfDate > $1.asOfDate }
            fields.append(StatementProbeResult.Field(name: type, years: reported.count,
                                                     latest: latestDate, latestValue: latestRaw,
                                                     currency: currency, series: series))
        }
        return StatementProbeResult(symbol: symbol, path: path, httpStatus: status,
                                    fields: fields, note: nil)
    }

    // MARK: - Annual series for Piotroski (best effort, cached)

    /// Annual fields the Piotroski and Altman scores need.
    static let balanceSheetTypes: [String] = [
        "annualNetIncome", "annualTotalAssets", "annualOperatingCashFlow", "annualTotalDebt",
        "annualCurrentAssets", "annualCurrentLiabilities", "annualDilutedAverageShares",
        "annualTotalRevenue", "annualGrossProfit", "annualRetainedEarnings",
        "annualStockholdersEquity", "annualTotalLiabilitiesNetMinorityInterest",
        "annualPretaxIncome", "annualInterestExpense", "annualOtherIncomeExpense",
        // Magic Formula: cash, the current part of debt, and net PP&E.
        "annualCashCashEquivalentsAndShortTermInvestments", "annualCurrentDebtAndCapitalLeaseObligation",
        "annualNetPPE"
    ]

    static let annualCacheTTL: TimeInterval = 24 * 60 * 60

    struct AnnualSeriesCache: Codable {
        let series: [String: [AnnualPoint]]
    }

    /// Annual history for the Piotroski fields, keyed by Yahoo type name. Cached for
    /// 24 hours. Failures are not cached, so a transient error doesn't stick.
    public func fetchAnnualSeries(symbol: String) async -> [String: [AnnualPoint]]? {
        // "v3" keeps entries cached before the Magic Formula fields were added from being reused.
        let key = "annualseries.v3.\(symbol)"
        let cache = DataCache.shared
        if let age = cache.age(key: key), age < Self.annualCacheTTL,
           let hit = cache.load(AnnualSeriesCache.self, key: key) {
            return hit.series
        }
        guard let series = await requestAnnualSeries(symbol: symbol) else { return nil }
        cache.save(AnnualSeriesCache(series: series), key: key)
        return series
    }

    private func requestAnnualSeries(symbol: String) async -> [String: [AnnualPoint]]? {
        let types = Self.balanceSheetTypes.joined(separator: ",")
        let now = Int(Date().timeIntervalSince1970)
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        let base = "https://query2.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/timeseries/\(encoded)?type=\(types)&period1=1262304000&period2=\(now)"
        guard let firstURL = URL(string: base) else { return nil }
        do {
            var (data, response) = try await session.data(for: makeRequest(firstURL))
            // Same pattern as the other endpoints: add the crumb only if Yahoo refuses.
            if let http = response as? HTTPURLResponse, http.statusCode == 401 || http.statusCode == 403 {
                guard let crumb = try? await crumbs.crumb(session: session, userAgent: Self.userAgent) else {
                    return nil
                }
                let encodedCrumb = crumb.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? crumb
                guard let retryURL = URL(string: base + "&crumb=\(encodedCrumb)") else { return nil }
                (data, response) = try await session.data(for: makeRequest(retryURL))
            }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return Self.parseAnnualSeries(data)
        } catch {
            return nil
        }
    }

    static func parseAnnualSeries(_ data: Data) -> [String: [AnnualPoint]]? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let ts = root["timeseries"] as? [String: Any],
              let results = ts["result"] as? [[String: Any]] else { return nil }
        var out: [String: [AnnualPoint]] = [:]
        for result in results {
            for (key, value) in result where key.hasPrefix("annual") {
                guard let rows = value as? [[String: Any]] else { continue }
                var points: [AnnualPoint] = []
                for row in rows {
                    guard let date = row["asOfDate"] as? String,
                          let raw = (row["reportedValue"] as? [String: Any])?["raw"] as? Double else { continue }
                    points.append(AnnualPoint(asOfDate: date, value: raw))
                }
                if !points.isEmpty {
                    out[key] = points.sorted { $0.asOfDate > $1.asOfDate }
                }
            }
        }
        return out.isEmpty ? nil : out
    }

    // MARK: - Peer valuation (cached)

    /// Cached trailing P/E for one peer. `pe` is nil for a miss, which is cached
    /// too, so a peer with no usable P/E isn't re-requested on every detail open.
    struct PeerPECache: Codable {
        let pe: Double?
    }

    static let peerCacheTTL: TimeInterval = 24 * 60 * 60

    /// Trailing P/E for each peer, best-effort. Each symbol is cached for 24 hours.
    public func fetchPeerTrailingPEs(symbols: [String]) async -> [String: Double] {
        await withTaskGroup(of: (String, Double?).self) { group -> [String: Double] in
            for symbol in symbols {
                group.addTask {
                    let pe = await self.cachedTrailingPE(symbol: symbol)
                    return (symbol, pe)
                }
            }
            var out: [String: Double] = [:]
            for await (symbol, pe) in group {
                if let pe { out[symbol] = pe }
            }
            return out
        }
    }

    private func cachedTrailingPE(symbol: String) async -> Double? {
        let key = "peerpe.\(symbol)"
        let cache = DataCache.shared
        if let age = cache.age(key: key), age < Self.peerCacheTTL,
           let hit = cache.load(PeerPECache.self, key: key) {
            return hit.pe
        }
        let f = await fetchFundamentals(symbol: symbol)
        var pe: Double? = nil
        if let raw = f.trailingPE, raw > 0, raw.isFinite { pe = raw }
        cache.save(PeerPECache(pe: pe), key: key)
        return pe
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
        let modules = "summaryDetail,defaultKeyStatistics,financialData,calendarEvents,netSharePurchaseActivity"
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

    // MARK: - Profile (best effort)

    public func fetchProfile(symbol: String) async -> StockProfile {
        do { return try await requestProfile(symbol: symbol, retryOnAuth: true) }
        catch { return StockProfile() }
    }

    private func requestProfile(symbol: String, retryOnAuth: Bool) async throws -> StockProfile {
        let crumb = try await crumbs.crumb(session: session, userAgent: Self.userAgent)
        let modules = "assetProfile,quoteType,fundProfile,topHoldings"
        let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        let encodedCrumb = crumb.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? crumb
        guard let url = URL(string:
            "https://query2.finance.yahoo.com/v10/finance/quoteSummary/\(encodedSymbol)?modules=\(modules)&crumb=\(encodedCrumb)")
        else { throw YahooError.badURL }

        let (data, response) = try await session.data(for: makeRequest(url))
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 && retryOnAuth {
                await crumbs.invalidate()
                return try await requestProfile(symbol: symbol, retryOnAuth: false)
            }
            if !(200...299).contains(http.statusCode) { throw YahooError.http(http.statusCode) }
        }
        let decoded = try JSONDecoder().decode(QuoteSummaryResponse.self, from: data)
        guard let r = decoded.quoteSummary?.result?.first else { throw YahooError.empty }
        return Self.profile(from: r)
    }

    static func profile(from r: QuoteSummaryResponse.Result) -> StockProfile {
        var p = StockProfile()
        p.quoteType = r.quoteType?.quoteType
        p.sector = r.assetProfile?.sector
        p.industry = r.assetProfile?.industry
        p.country = r.assetProfile?.country
        p.website = r.assetProfile?.website
        p.summary = r.assetProfile?.longBusinessSummary
        p.employees = r.assetProfile?.fullTimeEmployees
        p.category = r.fundProfile?.categoryName
        p.family = r.fundProfile?.family
        if let th = r.topHoldings {
            p.stockPct = th.stockPosition?.raw
            p.bondPct = th.bondPosition?.raw
            p.cashPct = th.cashPosition?.raw
            p.otherPct = th.otherPosition?.raw
            p.sectorWeights = (th.sectorWeightings ?? []).compactMap { dict -> StockProfile.Weight? in
                guard let pair = dict.first, let raw = pair.value.raw, raw > 0 else { return nil }
                return StockProfile.Weight(name: prettySector(pair.key), pct: raw)
            }.sorted { $0.pct > $1.pct }
            p.topHoldings = (th.holdings ?? []).compactMap { h -> StockProfile.Weight? in
                guard let raw = h.holdingPercent?.raw, raw > 0 else { return nil }
                return StockProfile.Weight(name: h.holdingName ?? h.symbol ?? "—", pct: raw)
            }
        }
        return p
    }

    // MARK: - Earnings history (best effort)

    public func fetchEarnings(symbol: String) async -> EarningsHistory {
        do { return try await requestEarnings(symbol: symbol, retryOnAuth: true) }
        catch { return EarningsHistory() }
    }

    private func requestEarnings(symbol: String, retryOnAuth: Bool) async throws -> EarningsHistory {
        let crumb = try await crumbs.crumb(session: session, userAgent: Self.userAgent)
        let modules = "earnings"
        let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        let encodedCrumb = crumb.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? crumb
        guard let url = URL(string:
            "https://query2.finance.yahoo.com/v10/finance/quoteSummary/\(encodedSymbol)?modules=\(modules)&crumb=\(encodedCrumb)")
        else { throw YahooError.badURL }

        let (data, response) = try await session.data(for: makeRequest(url))
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 && retryOnAuth {
                await crumbs.invalidate()
                return try await requestEarnings(symbol: symbol, retryOnAuth: false)
            }
            if !(200...299).contains(http.statusCode) { throw YahooError.http(http.statusCode) }
        }
        let decoded = try JSONDecoder().decode(QuoteSummaryResponse.self, from: data)
        guard let r = decoded.quoteSummary?.result?.first else { throw YahooError.empty }
        return Self.earnings(from: r)
    }

    static func earnings(from r: QuoteSummaryResponse.Result) -> EarningsHistory {
        var h = EarningsHistory()
        guard let e = r.earnings else { return h }
        let fin = e.financialsChart?.quarterly ?? []
        let eps = e.earningsChart?.quarterly ?? []

        // Merge the two quarterly series on their shared label ("1Q2024"),
        // preserving Yahoo's chronological (oldest → newest) ordering.
        var byLabel: [String: EarningsHistory.Quarter] = [:]
        var order: [String] = []

        for row in fin {
            guard let label = row.date else { continue }
            if byLabel[label] == nil { order.append(label) }
            byLabel[label] = EarningsHistory.Quarter(
                label: label, revenue: row.revenue?.raw, earnings: row.earnings?.raw,
                epsActual: byLabel[label]?.epsActual, epsEstimate: byLabel[label]?.epsEstimate)
        }
        for row in eps {
            guard let label = row.date else { continue }
            if byLabel[label] == nil { order.append(label) }
            let prev = byLabel[label]
            byLabel[label] = EarningsHistory.Quarter(
                label: label, revenue: prev?.revenue, earnings: prev?.earnings,
                epsActual: row.actual?.raw, epsEstimate: row.estimate?.raw)
        }

        h.quarters = order.compactMap { byLabel[$0] }
        return h
    }

    /// Market benchmark for relative-strength: the TSX Composite for Canadian
    /// listings (.TO / .V), otherwise the S&P 500.
    public static func benchmark(for symbol: String) -> (symbol: String, name: String) {
        let s = symbol.uppercased()
        if s.hasSuffix(".TO") || s.hasSuffix(".V") { return ("^GSPTSE", "TSX Composite") }
        return ("^GSPC", "S&P 500")
    }

    private static func prettySector(_ key: String) -> String {
        let map = [
            "realestate": "Real Estate",
            "consumer_cyclical": "Consumer Cyclical",
            "basic_materials": "Basic Materials",
            "consumer_defensive": "Consumer Defensive",
            "technology": "Technology",
            "communication_services": "Communication Services",
            "financial_services": "Financial Services",
            "utilities": "Utilities",
            "industrials": "Industrials",
            "energy": "Energy",
            "healthcare": "Healthcare"
        ]
        if let v = map[key] { return v }
        return key.replacingOccurrences(of: "_", with: " ").capitalized
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
        // Prior *trading day* close (daily change), not the chart-range start
        // close — otherwise a 1-year request reports a ~1-year change.
        let prev = meta.previousClose ?? meta.chartPreviousClose ?? price
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
        f.shortPercentOfFloat = r.defaultKeyStatistics?.shortPercentOfFloat?.raw
        f.shortRatio = r.defaultKeyStatistics?.shortRatio?.raw
        f.insiderNetShares = r.netSharePurchaseActivity?.netShares?.raw
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
