import Foundation

// MARK: - Chart endpoint (v8/finance/chart)

public struct ChartResponse: Decodable {
    public let chart: Chart

    public struct Chart: Decodable {
        public let result: [Result]?
        public let error: YError?
    }

    public struct YError: Decodable {
        public let code: String?
        public let description: String?
    }

    public struct Result: Decodable {
        public let meta: Meta
        public let timestamp: [Double]?
        public let indicators: Indicators
    }

    public struct Meta: Decodable {
        public let currency: String?
        public let symbol: String?
        public let exchangeName: String?
        public let regularMarketPrice: Double?
        public let chartPreviousClose: Double?
        public let previousClose: Double?
        public let shortName: String?
        public let longName: String?
        public let regularMarketTime: Double?
    }

    public struct Indicators: Decodable {
        public let quote: [QuoteSeries]?
        public let adjclose: [AdjCloseSeries]?
    }

    public struct QuoteSeries: Decodable {
        public let open: [Double?]?
        public let high: [Double?]?
        public let low: [Double?]?
        public let close: [Double?]?
        public let volume: [Double?]?
    }

    public struct AdjCloseSeries: Decodable {
        public let adjclose: [Double?]?
    }
}

// MARK: - quoteSummary endpoint (v10/finance/quoteSummary)

/// Yahoo wraps most numeric fields as `{ "raw": 1.23, "fmt": "1.23" }`.
public struct YValue: Decodable {
    public let raw: Double?
}

public struct QuoteSummaryResponse: Decodable {
    public let quoteSummary: QuoteSummary?

    public struct QuoteSummary: Decodable {
        public let result: [Result]?
        public let error: ChartResponse.YError?
    }

    public struct Result: Decodable {
        public let summaryDetail: SummaryDetail?
        public let defaultKeyStatistics: KeyStatistics?
        public let financialData: FinancialData?
        public let calendarEvents: CalendarEvents?
        public let netSharePurchaseActivity: NetSharePurchaseActivity?
    }

    public struct NetSharePurchaseActivity: Decodable {
        public let netShares: YValue?
        public let netPercentInsiderShares: YValue?
    }

    public struct SummaryDetail: Decodable {
        public let marketCap: YValue?
        public let trailingPE: YValue?
        public let forwardPE: YValue?
        public let dividendYield: YValue?
        public let dividendRate: YValue?
        public let exDividendDate: YValue?
        public let beta: YValue?
        public let fiftyTwoWeekHigh: YValue?
        public let fiftyTwoWeekLow: YValue?
    }

    public struct CalendarEvents: Decodable {
        public let earnings: Earnings?
        public let exDividendDate: YValue?
        public struct Earnings: Decodable {
            public let earningsDate: [YValue]?
        }
    }

    public struct KeyStatistics: Decodable {
        public let priceToBook: YValue?
        public let pegRatio: YValue?
        public let forwardPE: YValue?
        public let beta: YValue?
        public let shortPercentOfFloat: YValue?
        public let shortRatio: YValue?
    }

    public struct FinancialData: Decodable {
        public let profitMargins: YValue?
        public let returnOnEquity: YValue?
        public let debtToEquity: YValue?
        public let revenueGrowth: YValue?
        public let earningsGrowth: YValue?
        public let recommendationKey: String?
        public let numberOfAnalystOpinions: YValue?
        public let targetMeanPrice: YValue?
    }
}
