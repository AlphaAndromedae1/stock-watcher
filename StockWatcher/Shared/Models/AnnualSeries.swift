import Foundation

/// One reported annual value from Yahoo's fundamentals timeseries.
public struct AnnualPoint: Codable, Equatable, Sendable {
    public let asOfDate: String
    public let value: Double
    /// The currency the statement reports in, e.g. "USD" for a company listed in Canada.
    public let currency: String?

    public init(asOfDate: String, value: Double, currency: String? = nil) {
        self.asOfDate = asOfDate
        self.value = value
        self.currency = currency
    }
}

/// One fiscal year-end, with every field that reported a value for it.
public struct AnnualYear: Equatable, Sendable {
    public let asOf: String
    /// Keyed by Yahoo's type name, e.g. "annualNetIncome".
    public let values: [String: Double]

    public init(asOf: String, values: [String: Double]) {
        self.asOf = asOf
        self.values = values
    }
}

public enum AnnualYears {
    /// Aligns per-field series into one row per fiscal year-end, newest first.
    public static func build(_ series: [String: [AnnualPoint]], maxYears: Int = 4) -> [AnnualYear] {
        var dates = Set<String>()
        for points in series.values {
            for point in points {
                dates.insert(point.asOfDate)
            }
        }
        let newestFirst = dates.sorted(by: >)
        var years: [AnnualYear] = []
        for date in newestFirst.prefix(maxYears) {
            var values: [String: Double] = [:]
            for (field, points) in series {
                if let match = points.first(where: { $0.asOfDate == date }) {
                    values[field] = match.value
                }
            }
            years.append(AnnualYear(asOf: date, values: values))
        }
        return years
    }
}
