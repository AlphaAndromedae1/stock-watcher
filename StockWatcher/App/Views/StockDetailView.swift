import SwiftUI
import WidgetKit
import UIKit

struct StockDetailView: View {
    @StateObject private var model: StockDetailViewModel
    @State private var inWatchlist: Bool

    init(symbol: String, name: String) {
        _model = StateObject(wrappedValue: StockDetailViewModel(symbol: symbol, name: name))
        _inWatchlist = State(initialValue: WatchlistStore.shared.contains(symbol: symbol))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if let error = model.errorMessage, model.rating == nil {
                    errorCard(error)
                }
                ratingCard
                chartCard
                if let rating = model.rating {
                    breakdownCard(title: "Oscillators", group: rating.oscillators)
                    breakdownCard(title: "Moving Averages", group: rating.movingAverages)
                }
                fundamentalsCard
                disclaimer
            }
            .padding()
        }
        .navigationTitle(displaySymbol)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleWatchlist()
                } label: {
                    Image(systemName: inWatchlist ? "star.fill" : "star")
                }
                .accessibilityLabel(inWatchlist ? "Remove from watchlist" : "Add to watchlist")
            }
        }
        .task { await model.loadAll() }
    }

    private var displaySymbol: String {
        model.symbol.replacingOccurrences(of: ".TO", with: "")
            .replacingOccurrences(of: ".V", with: "")
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.quote?.shortName ?? model.name)
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Fmt.price(model.quote?.price))
                    .font(.largeTitle.bold().monospacedDigit())
                if let q = model.quote {
                    HStack(spacing: 4) {
                        Image(systemName: q.isUp ? "arrow.up" : "arrow.down").font(.caption.bold())
                        Text("\(Fmt.signed(q.change))  (\(Fmt.signedPercent(q.changePercent)))")
                            .font(.subheadline.monospacedDigit())
                    }
                    .foregroundStyle(Color.forChange(q.isUp))
                }
            }
            if let q = model.quote {
                Text("\(q.exchange ?? "TSX") • \(q.currency ?? "CAD")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Rating

    private var ratingCard: some View {
        Card {
            if let rating = model.rating {
                VStack(spacing: 14) {
                    Text("Technical Rating")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    RatingGaugeView(average: rating.summaryAverage, recommendation: rating.summary)
                    Divider()
                    HStack(spacing: 12) {
                        subRating("Oscillators", rating.oscillators)
                        Divider().frame(height: 42)
                        subRating("Moving Avgs", rating.movingAverages)
                    }
                    Text("Based on \(rating.allResults.count) indicators on daily data.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if model.isLoadingRating {
                ProgressView("Analyzing…").frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                Text("Rating unavailable.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            }
        }
    }

    private func subRating(_ title: String, _ group: RatingGroup) -> some View {
        VStack(spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(group.recommendation.label)
                .font(.subheadline.bold())
                .foregroundStyle(group.recommendation.color)
            Text("\(group.buyCount)B · \(group.neutralCount)N · \(group.sellCount)S")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Chart

    private var chartCard: some View {
        Card {
            VStack(spacing: 12) {
                Picker("Range", selection: Binding(
                    get: { model.range },
                    set: { model.setRange($0) }
                )) {
                    ForEach(ChartRange.allCases, id: \.self) { r in
                        Text(r.label).tag(r)
                    }
                }
                .pickerStyle(.segmented)

                if model.chartCandles.isEmpty {
                    if model.isLoadingChart {
                        ProgressView().frame(height: 200)
                    } else {
                        Text("No chart data.").foregroundStyle(.secondary).frame(height: 200)
                    }
                } else {
                    PriceChartView(candles: model.chartCandles)
                        .opacity(model.isLoadingChart ? 0.4 : 1)
                }
            }
        }
    }

    // MARK: Breakdown

    private func breakdownCard(title: String, group: RatingGroup) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    Text(group.recommendation.label)
                        .font(.subheadline.bold())
                        .foregroundStyle(group.recommendation.color)
                }
                TallyRow(group: group)
                Divider()
                ForEach(group.results) { r in
                    IndicatorRow(result: r)
                    if r.id != group.results.last?.id { Divider().opacity(0.4) }
                }
            }
        }
    }

    // MARK: Fundamentals

    private var fundamentalsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Fundamentals").font(.headline)
                    Spacer()
                    if let score = model.healthScore {
                        Text("Health \(score)/100")
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }
                }

                if model.fundamentals.isEmpty {
                    Text("Fundamental data isn’t available right now (Yahoo throttles this endpoint). Pull to refresh later — the technical rating above doesn’t depend on it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    keyStats
                    if !model.fundamentalChecks.isEmpty {
                        Divider()
                        ForEach(model.fundamentalChecks) { check in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: check.verdict.systemImage)
                                    .foregroundStyle(check.verdict.color)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(check.title).font(.subheadline.weight(.medium))
                                    Text(check.detail).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    analystTarget
                }
            }
        }
    }

    private var keyStats: some View {
        let f = model.fundamentals
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            stat("Market cap", Fmt.bigNumber(f.marketCap))
            stat("P/E (ttm)", Fmt.number(f.trailingPE))
            stat("Fwd P/E", Fmt.number(f.forwardPE))
            stat("Price/Book", Fmt.number(f.priceToBook))
            stat("Div yield", Fmt.percentFromFraction(f.dividendYield))
            stat("Beta", Fmt.number(f.beta))
            stat("52w high", Fmt.price(f.fiftyTwoWeekHigh))
            stat("52w low", Fmt.price(f.fiftyTwoWeekLow))
        }
    }

    @ViewBuilder
    private var analystTarget: some View {
        let f = model.fundamentals
        if f.targetMeanPrice != nil || f.recommendationKey != nil {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Analyst consensus").font(.caption).foregroundStyle(.secondary)
                    Text((f.recommendationKey ?? "—").replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.subheadline.bold())
                }
                Spacer()
                if let t = f.targetMeanPrice {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Mean target").font(.caption).foregroundStyle(.secondary)
                        Text(Fmt.price(t)).font(.subheadline.bold().monospacedDigit())
                    }
                }
            }
            if let n = f.numberOfAnalysts {
                Text("From \(n) analysts").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.monospacedDigit())
        }
        .padding(.vertical, 2)
    }

    // MARK: misc

    private func errorCard(_ message: String) -> some View {
        Card {
            Label(message, systemImage: "wifi.exclamationmark")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var disclaimer: some View {
        Text("For research and education only — not financial advice. Ratings are algorithmic signals derived from price data (methodology mirrors TradingView). Data from Yahoo Finance and may be delayed. Always do your own research.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.top, 4)
    }

    private func toggleWatchlist() {
        if inWatchlist {
            WatchlistStore.shared.remove(symbol: model.symbol)
        } else {
            WatchlistStore.shared.add(WatchItem(symbol: model.symbol, name: model.quote?.shortName ?? model.name))
        }
        inWatchlist.toggle()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Simple rounded card container.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
