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

// MARK: - search endpoint (v1/finance/search) — symbol autocomplete

public struct YahooSearchResponse: Decodable {
    public let quotes: [Hit]?

    public struct Hit: Decodable {
        public let symbol: String?
        public let shortname: String?
        public let longname: String?
        public let exchDisp: String?      // e.g. "Toronto", "NASDAQ"
        public let quoteType: String?     // EQUITY, ETF, INDEX, CRYPTOCURRENCY, …
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
        public let assetProfile: AssetProfile?
        public let quoteType: QuoteTypeInfo?
        public let fundProfile: FundProfile?
        public let topHoldings: TopHoldings?
        public let earnings: EarningsModule?
    }

    /// `earnings` module: quarterly revenue/net-income and EPS actual-vs-estimate.
    /// We only decode the *quarterly* arrays (their `date` is a string like
    /// "1Q2024"); the `yearly` arrays are intentionally left out because their
    /// `date` is a bare integer year, which would break this decode.
    public struct EarningsModule: Decodable {
        public let earningsChart: EarningsChart?
        public let financialsChart: FinancialsChart?

        public struct EarningsChart: Decodable {
            public let quarterly: [EPSQuarter]?
            public struct EPSQuarter: Decodable {
                public let date: String?        // "1Q2024"
                public let actual: YValue?
                public let estimate: YValue?
            }
        }

        public struct FinancialsChart: Decodable {
            public let quarterly: [FinRow]?
            public struct FinRow: Decodable {
                public let date: String?        // "1Q2024"
                public let revenue: YValue?
                public let earnings: YValue?    // net income
            }
        }
    }

    public struct AssetProfile: Decodable {
        public let sector: String?
        public let industry: String?
        public let country: String?
        public let website: String?
        public let longBusinessSummary: String?
        public let fullTimeEmployees: Int?
    }

    public struct QuoteTypeInfo: Decodable {
        public let quoteType: String?
    }

    public struct FundProfile: Decodable {
        public let family: String?
        public let categoryName: String?
    }

    public struct TopHoldings: Decodable {
        public let stockPosition: YValue?
        public let bondPosition: YValue?
        public let cashPosition: YValue?
        public let otherPosition: YValue?
        public let holdings: [HoldingRow]?
        public let sectorWeightings: [[String: YValue]]?

        public struct HoldingRow: Decodable {
            public let symbol: String?
            public let holdingName: String?
            public let holdingPercent: YValue?
        }
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
