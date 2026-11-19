import SwiftUI
import WidgetKit
import UIKit
import Charts

struct StockDetailView: View {
    @StateObject private var model: StockDetailViewModel
    @State private var inWatchlist: Bool
    @State private var showPositionEditor = false
    @State private var chartStyle: ChartStyleKind = .line
    @State private var alerts: [PriceAlert] = []
    @State private var showAddPrice = false
    @State private var addKind: PriceAlert.Kind = .priceAbove

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
                Group {
                    if model.composite != nil { scoreCard }
                    ratingCard
                    chartCard
                }
                Group {
                    positionCard
                    alertsCard
                }
                if let rating = model.rating {
                    breakdownCard(title: "Oscillators", group: rating.oscillators)
                    breakdownCard(title: "Moving Averages", group: rating.movingAverages)
                }
                Group {
                    fundamentalsCard
                    newsCard
                    disclaimer
                }
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
        .task {
            reloadAlerts()
            await model.loadAll()
        }
        .sheet(isPresented: $showAddPrice) {
            AddPriceAlertSheet(
                symbol: displaySymbol,
                kind: addKind,
                suggested: model.quote?.price ?? 0,
                onSave: { value in
                    AlertStore.shared.add(PriceAlert(symbol: model.symbol, name: model.name,
                                                     kind: addKind, threshold: value))
                    reloadAlerts()
                    showAddPrice = false
                })
        }
        .sheet(isPresented: $showPositionEditor) {
            PositionEditor(
                symbol: displaySymbol,
                holding: model.holding,
                onSave: { shares, cost in
                    model.saveHolding(shares: shares, costBasis: cost)
                    showPositionEditor = false
                },
                onRemove: {
                    model.removeHolding()
                    showPositionEditor = false
                })
        }
    }

    // MARK: Alerts

    private var alertsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Alerts").font(.headline)
                    Spacer()
                    if !SettingsStore.shared.alertsEnabled {
                        Text("Off").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !SettingsStore.shared.alertsEnabled {
                    Text("Turn on notifications in Settings for these to fire.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Toggle("Notify on Buy signal", isOn: ratingBinding(.ratingBuy))
                    .font(.subheadline)
                Toggle("Notify on Sell signal", isOn: ratingBinding(.ratingSell))
                    .font(.subheadline)

                let priceAlerts = alerts.filter { $0.kind == .priceAbove || $0.kind == .priceBelow }
                if !priceAlerts.isEmpty {
                    Divider()
                    ForEach(priceAlerts) { a in
                        HStack {
                            Image(systemName: a.kind == .priceAbove ? "arrow.up.circle" : "arrow.down.circle")
                                .foregroundStyle(.secondary)
                            Text(a.describe).font(.subheadline)
                            Spacer()
                            Button(role: .destructive) {
                                AlertStore.shared.remove(id: a.id); reloadAlerts()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Divider()
                HStack {
                    Button { addKind = .priceAbove; showAddPrice = true } label: {
                        Label("Price above", systemImage: "arrow.up")
                    }
                    Spacer()
                    Button { addKind = .priceBelow; showAddPrice = true } label: {
                        Label("Price below", systemImage: "arrow.down")
                    }
                }
                .font(.subheadline)
                .buttonStyle(.bordered)
            }
        }
    }

    private func ratingBinding(_ kind: PriceAlert.Kind) -> Binding<Bool> {
        Binding(
            get: { AlertStore.shared.hasRatingAlert(symbol: model.symbol, kind: kind) },
            set: { on in
                AlertStore.shared.setRatingAlert(symbol: model.symbol, name: model.name, kind: kind, on: on)
                reloadAlerts()
            })
    }

    private func reloadAlerts() {
        alerts = AlertStore.shared.alerts(for: model.symbol)
    }

    // MARK: Position / P&L

    private var positionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Your Position").font(.headline)
                    Spacer()
                    Button(model.holding == nil ? "Add" : "Edit") { showPositionEditor = true }
                        .font(.subheadline)
                }
                if let h = model.holding, let price = model.quote?.price {
                    let gain = h.gain(at: price)
                    let up = gain >= 0
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        stat("Shares", Fmt.number(h.shares, decimals: h.shares.rounded() == h.shares ? 0 : 2))
                        stat("Avg cost", Fmt.price(h.costBasis))
                        stat("Market value", Fmt.price(h.marketValue(at: price)))
                        stat("Cost basis", Fmt.price(h.cost))
                    }
                    Divider()
                    HStack {
                        Text("Total return").font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(Fmt.signedMoney(gain))  (\(Fmt.signedPercent(h.gainPercent(at: price))))")
                            .font(.subheadline.monospacedDigit().bold())
                            .foregroundStyle(Color.forChange(up))
                    }
                } else {
                    Text("Add your shares and average cost to track gains/losses here and on your watchlist.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
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

    // MARK: Stock Watcher Score (custom composite)

    private var scoreCard: some View {
        Card {
            if let c = model.composite {
                VStack(spacing: 14) {
                    HStack {
                        Text("Stock Watcher Score").font(.headline)
                        Spacer()
                        Text(c.band.label)
                            .font(.subheadline.bold())
                            .foregroundStyle(c.band.color)
                    }
                    HStack(alignment: .center, spacing: 18) {
                        ScoreRing(score: c.score, color: c.band.color)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(c.components) { comp in
                                componentBar(comp, tint: c.band.color)
                            }
                        }
                    }
                    scoreTrend(c.band.color)
                    Text("A weighted blend of the signals below — research aid, not advice.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private func scoreTrend(_ color: Color) -> some View {
        if model.scoreHistory.count >= 2 {
            VStack(alignment: .leading, spacing: 2) {
                Text("Score trend").font(.caption2).foregroundStyle(.secondary)
                Chart(model.scoreHistory) { sample in
                    LineMark(x: .value("Date", sample.date),
                             y: .value("Score", sample.score))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(color)
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 40)
            }
        }
    }

    private func componentBar(_ comp: CompositeEvaluator.Component, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(comp.label).font(.caption.weight(.medium))
                Spacer()
                Text(comp.detail).font(.caption2).foregroundStyle(.secondary)
                Text("\(Int(comp.score))")
                    .font(.caption.monospacedDigit().bold())
                    .frame(minWidth: 26, alignment: .trailing)
            }
            ProgressView(value: comp.score, total: 100)
                .tint(tint)
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

                Picker("Style", selection: $chartStyle) {
                    ForEach(ChartStyleKind.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
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
                    Group {
                        if chartStyle == .line {
                            PriceChartView(candles: model.chartCandles)
                        } else {
                            CandleChartView(candles: model.chartCandles)
                        }
                    }
                    .opacity(model.isLoadingChart ? 0.4 : 1)

                    Divider()
                    VolumeChartView(candles: model.chartCandles)
                    RSIChartView(candles: model.chartCandles)
                    MACDChartView(candles: model.chartCandles)
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
                    keyDates
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

    @ViewBuilder
    private var keyDates: some View {
        let f = model.fundamentals
        if f.nextEarningsDate != nil || f.exDividendDate != nil || f.dividendRate != nil {
            Divider()
            HStack(alignment: .top) {
                if let e = f.nextEarningsDate {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Next earnings").font(.caption).foregroundStyle(.secondary)
                        Text(Fmt.date(e)).font(.subheadline)
                    }
                }
                Spacer()
                if let x = f.exDividendDate {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Ex-dividend").font(.caption).foregroundStyle(.secondary)
                        Text(Fmt.date(x)).font(.subheadline)
                        if let rate = f.dividendRate {
                            Text("\(Fmt.price(rate))/yr").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
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
            stat("Short % float", Fmt.percentFromFraction(f.shortPercentOfFloat))
            stat("Short ratio", Fmt.number(f.shortRatio, decimals: 1))
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

    // MARK: News

    @ViewBuilder
    private var newsCard: some View {
        if !model.news.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("News").font(.headline)
                    ForEach(model.news) { item in
                        if let url = item.link {
                            Link(destination: url) { newsRow(item) }
                                .buttonStyle(.plain)
                        } else {
                            newsRow(item)
                        }
                        if item.id != model.news.last?.id { Divider().opacity(0.4) }
                    }
                }
            }
        }
    }

    private func newsRow(_ item: NewsItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.subheadline).lineLimit(3)
                if let d = item.date {
                    Text(d, format: .relative(presentation: .named))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "arrow.up.right.square")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
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

enum ChartStyleKind: String, CaseIterable {
    case line = "Line"
    case candles = "Candles"
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

/// Sheet to enter/edit a holding (shares + average cost).
struct PositionEditor: View {
    let symbol: String
    let holding: Holding?
    let onSave: (Double, Double) -> Void
    let onRemove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sharesText: String
    @State private var costText: String

    init(symbol: String, holding: Holding?,
         onSave: @escaping (Double, Double) -> Void,
         onRemove: @escaping () -> Void) {
        self.symbol = symbol
        self.holding = holding
        self.onSave = onSave
        self.onRemove = onRemove
        _sharesText = State(initialValue: holding.map { Self.trimmed($0.shares) } ?? "")
        _costText = State(initialValue: holding.map { Self.trimmed($0.costBasis) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("\(symbol) position") {
                    HStack {
                        Text("Shares")
                        Spacer()
                        TextField("0", text: $sharesText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Avg cost / share")
                        Spacer()
                        TextField("0.00", text: $costText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                if holding != nil {
                    Section {
                        Button("Remove position", role: .destructive) { onRemove() }
                    }
                }
            }
            .navigationTitle("Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(Self.parse(sharesText), Self.parse(costText)) }
                }
            }
        }
    }

    private static func parse(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private static func trimmed(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(v)
    }
}

/// Sheet to enter a price threshold for a price alert.
struct AddPriceAlertSheet: View {
    let symbol: String
    let kind: PriceAlert.Kind
    let suggested: Double
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(symbol: String, kind: PriceAlert.Kind, suggested: Double, onSave: @escaping (Double) -> Void) {
        self.symbol = symbol
        self.kind = kind
        self.suggested = suggested
        self.onSave = onSave
        _text = State(initialValue: suggested > 0 ? String(format: "%.2f", suggested) : "")
    }

    private var title: String { kind == .priceAbove ? "Alert when above" : "Alert when below" }

    var body: some View {
        NavigationStack {
            Form {
                Section("\(symbol) — \(title)") {
                    HStack {
                        Text("Price")
                        Spacer()
                        TextField("0.00", text: $text)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("New Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let v = Double(text.replacingOccurrences(of: ",", with: "")) ?? 0
                        if v > 0 { onSave(v) } else { dismiss() }
                    }
                }
            }
        }
    }
}
