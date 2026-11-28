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
    @State private var showPlanEditor = false
    @State private var showSizer = false
    @State private var planRevision = 0

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
                    chartSignalsCard
                    relativeStrengthCard
                    quantCard
                    oddsCard
                }
                Group {
                    positionCard
                    planCard
                    alertsCard
                }
                if let rating = model.rating {
                    breakdownCard(title: "Oscillators", group: rating.oscillators)
                    breakdownCard(title: "Moving Averages", group: rating.movingAverages)
                }
                Group {
                    aboutCard
                    earningsCard
                    fundamentalsCard
                    piotroskiCard
                    altmanCard
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
        .sheet(isPresented: $showPlanEditor) {
            TradePlanEditor(
                symbol: displaySymbol,
                plan: TradePlanStore.shared.plan(for: model.symbol),
                onSave: { plan in
                    TradePlanStore.shared.save(plan, for: model.symbol)
                    planRevision += 1
                    Task { await model.runSim() }
                    showPlanEditor = false
                })
        }
        .sheet(isPresented: $showSizer) {
            PositionSizerSheet(
                symbol: displaySymbol,
                entry: model.quote?.price ?? 0,
                stop: TradePlanStore.shared.plan(for: model.symbol)?.stop,
                target: TradePlanStore.shared.plan(for: model.symbol)?.target)
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

    // MARK: Plan & Sizing

    private var planCard: some View {
        let plan = TradePlanStore.shared.plan(for: model.symbol)
        let price = model.quote?.price
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Plan & Sizing").font(.headline)
                    Spacer()
                    Button(plan == nil ? "Set plan" : "Edit") { showPlanEditor = true }
                        .font(.subheadline)
                }
                if let plan = plan {
                    HStack(spacing: 16) {
                        if let t = plan.target { planStat("Target", Fmt.price(t), Color.forChange(true)) }
                        if let s = plan.stop { planStat("Stop", Fmt.price(s), Color.forChange(false)) }
                        Spacer()
                        if let price = price, let rr = plan.rewardRisk(entry: price) {
                            planStat("Reward : Risk", String(format: "%.1f : 1", rr), .primary)
                        }
                    }
                } else {
                    Text("Set a target and a stop to see reward:risk — and the odds of hitting each in Possible Outcomes.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                Button { showSizer = true } label: {
                    Label("Position sizer", systemImage: "function")
                }
                .font(.subheadline)
            }
        }
        .id(planRevision)
    }

    private func planStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.monospacedDigit().bold()).foregroundStyle(color)
        }
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

    // MARK: Possible Outcomes (Monte Carlo)

    private var oddsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Possible Outcomes").font(.headline)
                    Spacer()
                    Picker("Horizon", selection: Binding(
                        get: { model.simHorizon },
                        set: { model.setSimHorizon($0) }
                    )) {
                        Text("1M").tag(21)
                        Text("3M").tag(63)
                        Text("1Y").tag(252)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
                if let s = model.sim {
                    let plan = TradePlanStore.shared.plan(for: model.symbol)
                    FanChartView(result: s, target: plan?.target, stop: plan?.stop)
                    oddsStats(s)
                } else {
                    ProgressView().frame(maxWidth: .infinity).frame(height: 150)
                }
                Text("Simulated from this stock's own ~1-year daily history (2,500 paths). A range of outcomes, not a prediction — it can't foresee earnings, gaps or news.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func oddsStats(_ s: MonteCarloResult) -> some View {
        func chg(_ v: Double) -> String { Fmt.signedPercent((v / s.startPrice - 1) * 100) }
        return LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                                   GridItem(.flexible(), alignment: .leading)], spacing: 10) {
            oddsCell("Median", "\(Fmt.price(s.p50)) (\(chg(s.p50)))")
            oddsCell("Chance higher", Fmt.percentFromFraction(s.probUp))
            oddsCell("Likely (50%)", "\(Fmt.price(s.p25)) – \(Fmt.price(s.p75))")
            oddsCell("Range (90%)", "\(Fmt.price(s.p5)) – \(Fmt.price(s.p95))")
            if let pt = s.probTarget {
                oddsCell("Hits target", Fmt.percentFromFraction(pt))
            }
            if let ps = s.probStop {
                oddsCell("Hits stop", Fmt.percentFromFraction(ps))
            }
        }
    }

    private func oddsCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.monospacedDigit().weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    HStack(spacing: 6) {
                        Image(systemName: rating.flow.systemImage).foregroundStyle(rating.flow.color)
                        Text(rating.flow.label)
                            .font(.caption.weight(.semibold)).foregroundStyle(rating.flow.color)
                        Text("· money flow").font(.caption2).foregroundStyle(.secondary)
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

    // MARK: Shared tints

    private var gainColor: Color { Pantone.emerald }
    private var lossColor: Color { Pantone.livingCoral }

    // MARK: Chart Signals (objective, rule-based)

    @ViewBuilder
    private var chartSignalsCard: some View {
        if !model.chartSignals.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Chart Signals").font(.headline)
                        Spacer()
                        Text("informational").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("Objective, rule-based readings from price & volume — not chart-pattern guesses, and never part of the Score.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(model.chartSignals) { sig in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: sig.systemImage)
                                .font(.subheadline)
                                .foregroundStyle(sig.bias.color)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(sig.title).font(.subheadline.bold())
                                Text(sig.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Piotroski F-Score (informational, never in the Score)

    @ViewBuilder
    private var piotroskiCard: some View {
        if let p = model.piotroski {
            Card { piotroskiContent(p) }
        } else if let note = model.piotroskiNote {
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Piotroski F-Score").font(.headline)
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func piotroskiContent(_ p: PiotroskiScore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Piotroski F-Score").font(.headline)
                Spacer()
                Text("\(p.score) of \(p.computable)")
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(piotroskiColor(p))
            }
            Text(piotroskiSummary(p))
                .font(.caption).foregroundStyle(.secondary)
            ForEach(p.tests) { t in
                piotroskiRow(t)
            }
            Text("Compares \(p.latestYear) with the years before it. Informational only, and not part of the Stock Watcher Score.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func piotroskiSummary(_ p: PiotroskiScore) -> String {
        var text = "Nine yes/no tests of profitability, cash flow, leverage, liquidity, dilution and efficiency. A common reading is 8–9 strong and 0–2 weak."
        if p.computable < 9 {
            text += " Tests without enough history are left out of the count."
        }
        return text
    }

    private func piotroskiColor(_ p: PiotroskiScore) -> Color {
        guard p.computable == 9 else { return Color.primary }
        if p.score >= 8 { return gainColor }
        if p.score <= 2 { return lossColor }
        return Pantone.ultimateGray
    }

    private func piotroskiRow(_ t: PiotroskiTest) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: piotroskiIcon(t.outcome))
                .foregroundStyle(piotroskiTint(t.outcome))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(t.title).font(.subheadline)
                Text(t.detail).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func piotroskiIcon(_ o: PiotroskiTest.Outcome) -> String {
        switch o {
        case .pass: return "checkmark.circle.fill"
        case .fail: return "xmark.circle.fill"
        case .unavailable: return "minus.circle"
        }
    }

    private func piotroskiTint(_ o: PiotroskiTest.Outcome) -> Color {
        switch o {
        case .pass: return gainColor
        case .fail: return lossColor
        case .unavailable: return Color.secondary
        }
    }

    // MARK: Altman Z″ score (informational, never in the Score)

    @ViewBuilder
    private var altmanCard: some View {
        if let z = model.altman {
            Card { altmanContent(z) }
        } else if let note = model.altmanNote {
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Altman Z″ score").font(.headline)
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func altmanContent(_ z: AltmanScore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Altman Z″ score").font(.headline)
                Spacer()
                Text(Fmt.number(z.z))
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(altmanColor(z.zone))
            }
            Text("\(z.zone.title). Above 2.6 is safe, 1.1 to 2.6 is grey, and below 1.1 is distress. Built for non-manufacturers, and a distress reading is a prompt to look closer, not a forecast.")
                .font(.caption).foregroundStyle(.secondary)
            altmanRow("Working capital ÷ assets", ratio: z.x1, weight: 6.56)
            altmanRow("Retained earnings ÷ assets", ratio: z.x2, weight: 3.26)
            altmanRow("EBIT ÷ assets", ratio: z.x3, weight: 6.72)
            altmanRow("Book equity ÷ liabilities", ratio: z.x4, weight: 1.05)
            if z.flagged, let share = z.otherIncomeShare {
                Text("Other income is \(Fmt.percentFromFraction(share, decimals: 0)) of EBIT this year, so EBIT includes non-operating items. Read this score with caution.")
                    .font(.caption).foregroundStyle(lossColor)
            }
            Text("Year-end \(z.latestYear). EBIT is pre-tax income plus interest expense. Informational only, and not part of the Stock Watcher Score.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func altmanRow(_ title: String, ratio: Double, weight: Double) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text("\(Fmt.percentFromFraction(ratio, decimals: 1)) → \(Fmt.number(weight * ratio))")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func altmanColor(_ zone: AltmanZone) -> Color {
        switch zone {
        case .safe: return gainColor
        case .grey: return Pantone.ultimateGray
        case .distress: return lossColor
        }
    }

    // MARK: Quant Checks (Tier 1, informational, never in the Score)

    private func quantHasContent(_ q: QuantSnapshot) -> Bool {
        if q.graham != nil || q.sector != nil { return true }
        if q.momentum != nil || q.volatility != nil { return true }
        if q.maxDrawdown != nil || q.avgDollarVolume != nil { return true }
        return q.withholding != nil
    }

    @ViewBuilder
    private var quantCard: some View {
        if let q = model.quant, quantHasContent(q) {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Quant Checks").font(.headline)
                        Spacer()
                        Text("informational").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("Simple measures from price, volume and valuation. Never part of the Score.")
                        .font(.caption).foregroundStyle(.secondary)
                    Group {
                        if let g = q.graham {
                            quantRow("Graham Number", value: Fmt.number(g.value),
                                     detail: grahamDetail(g),
                                     tint: g.marginOfSafety >= 0 ? gainColor : lossColor)
                        }
                        if let s = q.sector {
                            quantRow("Valuation vs \(s.sectorName) peers",
                                     value: Fmt.signedPercent(s.premium * 100),
                                     detail: sectorDetail(s))
                        }
                        if let m = q.momentum {
                            quantRow("Momentum (≈12-1)", value: Fmt.signedPercent(m * 100),
                                     detail: momentumDetail(q), tint: momentumTint(q))
                        }
                        if let v = q.volatility {
                            quantRow("Volatility (yearly)", value: Fmt.percentFromFraction(v, decimals: 0),
                                     detail: "Typical yearly swing, annualised from daily moves.")
                        }
                        if let dd = q.maxDrawdown {
                            quantRow("Max drawdown (1y)", value: Fmt.percentFromFraction(dd, decimals: 0),
                                     detail: drawdownDetail(q))
                        }
                        if let r = q.returnPerRisk {
                            quantRow("Return ÷ volatility", value: Fmt.number(r),
                                     detail: "One-year return per unit of volatility. Higher is better. No risk-free rate is subtracted, so this is not the Sharpe ratio.")
                        }
                        if let adv = q.avgDollarVolume {
                            quantRow("Avg daily value traded", value: Fmt.bigNumber(adv),
                                     detail: "About three months of average daily value. Thin trading can make it costly to exit.")
                        }
                        if let w = q.withholding {
                            quantRow("Withholding (\(SettingsStore.shared.taxAccount.title))",
                                     value: withholdingValue(w), detail: w.text)
                        }
                    }
                }
            }
        }
    }

    private func quantRow(_ title: String, value: String, detail: String, tint: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.subheadline.bold())
                Spacer(minLength: 8)
                Text(value)
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(tint ?? Color.primary)
            }
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func grahamDetail(_ g: GrahamValuation) -> String {
        if g.marginOfSafety >= 0 {
            return "Price is \(Fmt.percentFromFraction(g.marginOfSafety, decimals: 0)) below this conservative ceiling. It ignores growth, so treat it as a margin of safety, not a guarantee."
        }
        let above = -g.marginOfSafety
        return "Price is \(Fmt.percentFromFraction(above, decimals: 0)) above this ceiling. It ignores growth, so a premium is not automatically expensive."
    }

    private func sectorDetail(_ s: SectorValuation) -> String {
        "P/E \(Fmt.number(s.ownPE, decimals: 1)) vs a peer median of \(Fmt.number(s.peerMedianPE, decimals: 1)) across \(s.peerCount) same-sector TSX names. Sectors are broad, so treat this as context."
    }

    private func momentumDetail(_ q: QuantSnapshot) -> String {
        var text = "About 11 months of price change, skipping the latest month. Momentum tends to persist, but it is not a guarantee."
        if let b = q.benchmarkMomentum {
            text += " \(YahooService.benchmark(for: model.symbol).name): \(Fmt.signedPercent(b * 100))."
        }
        return text
    }

    private func momentumTint(_ q: QuantSnapshot) -> Color? {
        guard let m = q.momentum, let b = q.benchmarkMomentum else { return nil }
        return m >= b ? gainColor : lossColor
    }

    private func drawdownDetail(_ q: QuantSnapshot) -> String {
        var text = "Worst peak-to-trough fall in the last year."
        if let cur = q.currentDrawdown {
            text += " Now \(Fmt.percentFromFraction(-cur, decimals: 0)) below its high."
        }
        return text
    }

    private func withholdingValue(_ w: WithholdingNote) -> String {
        guard let drag = w.drag else { return "Varies" }
        return drag > 0 ? "\(Fmt.percentFromFraction(drag, decimals: 2))/yr" : "None"
    }

    // MARK: Relative Strength (vs. market benchmark)

    @ViewBuilder
    private var relativeStrengthCard: some View {
        if let rs = model.relativeStrength {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Relative Strength").font(.headline)
                        Spacer()
                        Text(rs.verdict.title)
                            .font(.caption.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(rsVerdictColor(rs.verdict).gradient, in: Capsule())
                    }
                    Text("Return vs the \(rs.benchmarkName). Positive means the stock is outpacing the market over that window.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(rs.windows) { w in rsRow(w) }
                }
            }
        }
    }

    private func rsVerdictColor(_ v: RelativeStrength.Verdict) -> Color {
        switch v {
        case .leading: return gainColor
        case .inLine:  return Pantone.ultimateGray
        case .lagging: return lossColor
        }
    }

    private func rsRow(_ w: RelativeStrength.Window) -> some View {
        HStack(spacing: 10) {
            Text(w.label).font(.subheadline.bold().monospacedDigit())
                .frame(width: 32, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text("Stock \(Fmt.signedPercent(w.stockReturn * 100))")
                    .font(.caption.monospacedDigit())
                Text("Index \(Fmt.signedPercent(w.indexReturn * 100))")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: w.excess >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2.bold())
                Text(Fmt.signedPercent(w.excess * 100))
                    .font(.subheadline.monospacedDigit().bold())
            }
            .foregroundStyle(w.excess >= 0 ? gainColor : lossColor)
        }
    }

    // MARK: Earnings Trend

    @ViewBuilder
    private var earningsCard: some View {
        if let e = model.earnings, !e.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Earnings Trend").font(.headline)
                        Spacer()
                        if let g = e.revenueTrend { trendBadge("Rev", g) }
                    }
                    Text("Last \(e.quarters.count) reported quarters.")
                        .font(.caption).foregroundStyle(.secondary)

                    if e.quarters.contains(where: { $0.revenue != nil }) {
                        Text("Revenue").font(.caption.bold()).foregroundStyle(.secondary)
                        Chart(e.quarters) { q in
                            if let rev = q.revenue {
                                BarMark(x: .value("Quarter", q.label),
                                        y: .value("Revenue", rev))
                                    .foregroundStyle(Color.accentColor.gradient)
                                    .cornerRadius(3)
                            }
                        }
                        .frame(height: 96)
                        .chartYAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let d = value.as(Double.self) { Text(Fmt.bigNumber(d)) }
                                }
                            }
                        }
                    }

                    if e.quarters.contains(where: { $0.epsActual != nil || $0.epsEstimate != nil }) {
                        Divider()
                        HStack {
                            Text("EPS (actual vs est.)").font(.caption.bold()).foregroundStyle(.secondary)
                            Spacer()
                        }
                        ForEach(e.quarters.reversed()) { q in
                            if q.epsActual != nil || q.epsEstimate != nil { epsRow(q) }
                        }
                    }
                }
            }
        }
    }

    private func trendBadge(_ label: String, _ g: Double) -> some View {
        let up = g >= 0
        return HStack(spacing: 3) {
            Image(systemName: up ? "arrow.up.right" : "arrow.down.right").font(.caption2.bold())
            Text("\(label) \(Fmt.signedPercent(g * 100))").font(.caption.bold())
        }
        .foregroundStyle(up ? gainColor : lossColor)
    }

    private func epsRow(_ q: EarningsHistory.Quarter) -> some View {
        HStack(spacing: 8) {
            Text(q.label).font(.caption.monospacedDigit())
                .frame(width: 58, alignment: .leading).foregroundStyle(.secondary)
            Spacer()
            if let est = q.epsEstimate {
                Text("est \(Fmt.number(est))").font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
            }
            if let act = q.epsActual {
                let beat = q.beatEstimate ?? true
                HStack(spacing: 3) {
                    Image(systemName: beat ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption2)
                    Text(Fmt.number(act)).font(.subheadline.monospacedDigit().bold())
                }
                .foregroundStyle(beat ? gainColor : lossColor)
            }
        }
    }

    // MARK: About / Profile

    @ViewBuilder
    private var aboutCard: some View {
        if let p = model.profile, !p.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("About").font(.headline)
                        Spacer()
                        if let t = p.quoteType {
                            Text(typeLabel(t))
                                .font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    if p.isFund { fundProfileView(p) } else { stockProfileView(p) }
                }
            }
        }
    }

    private func typeLabel(_ t: String) -> String {
        switch t.uppercased() {
        case "ETF": return "ETF"
        case "MUTUALFUND": return "Fund"
        case "EQUITY": return "Stock"
        case "INDEX": return "Index"
        default: return t.capitalized
        }
    }

    @ViewBuilder
    private func stockProfileView(_ p: StockProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let s = p.sector { aboutRow("Sector", s) }
            if let i = p.industry { aboutRow("Industry", i) }
            if let c = p.country { aboutRow("Country", c) }
            if let e = p.employees { aboutRow("Employees", Fmt.bigNumber(Double(e))) }
            if let sum = p.summary, !sum.isEmpty {
                Text(sum).font(.caption).foregroundStyle(.secondary).lineLimit(6)
            }
        }
    }

    @ViewBuilder
    private func fundProfileView(_ p: StockProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let cat = p.category { aboutRow("Category", cat) }
            if let fam = p.family { aboutRow("Provider", fam) }

            if p.stockPct != nil || p.bondPct != nil || p.cashPct != nil || p.otherPct != nil {
                Divider()
                Text("Asset mix").font(.caption).foregroundStyle(.secondary)
                let stock = p.stockPct ?? 0
                let bond = p.bondPct ?? 0
                let other = p.otherPct ?? 0
                let cash = p.cashPct ?? max(0, 1 - stock - bond - other)
                allocRow("Stocks", stock, Pantone.emerald)
                if bond > 0.0001 { allocRow("Bonds", bond, Pantone.classicBlue) }
                if cash > 0.0001 { allocRow("Cash", cash, Pantone.ultimateGray) }
                if other > 0.0001 { allocRow("Other", other, Pantone.marigold) }
            }

            if !p.sectorWeights.isEmpty {
                Divider()
                Text("Top sectors").font(.caption).foregroundStyle(.secondary)
                ForEach(p.sectorWeights.prefix(5)) { w in weightRow(w) }
            }

            if !p.topHoldings.isEmpty {
                Divider()
                Text("Top holdings").font(.caption).foregroundStyle(.secondary)
                ForEach(p.topHoldings.prefix(6)) { w in weightRow(w) }
            }
        }
    }

    private func aboutRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline).multilineTextAlignment(.trailing).lineLimit(2)
        }
    }

    private func allocRow(_ label: String, _ pct: Double, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption).frame(width: 52, alignment: .leading)
            ProgressView(value: min(max(pct, 0), 1), total: 1).tint(color)
            Text(Fmt.percentFromFraction(pct, decimals: 0))
                .font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
        }
    }

    private func weightRow(_ w: StockProfile.Weight) -> some View {
        HStack {
            Text(w.name).font(.subheadline).lineLimit(1)
            Spacer()
            Text(Fmt.percentFromFraction(w.pct, decimals: 1))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
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
                    HStack {
                        Text("News").font(.headline)
                        Spacer()
                        if let tone = model.newsTone {
                            HStack(spacing: 5) {
                                Circle().fill(tone.label.color).frame(width: 7, height: 7)
                                Text("Tone: \(tone.label.title)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(tone.label.color)
                            }
                        }
                    }
                    ForEach(model.news) { item in
                        if let url = item.link {
                            Link(destination: url) { newsRow(item) }
                                .buttonStyle(.plain)
                        } else {
                            newsRow(item)
                        }
                        if item.id != model.news.last?.id { Divider().opacity(0.4) }
                    }
                    Text("Headline tone is on-device sentiment — informational only, not part of the score.")
                        .font(.caption2).foregroundStyle(.tertiary)
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

/// Sheet to set a target and stop (trade plan) for a stock.
struct TradePlanEditor: View {
    let symbol: String
    let plan: TradePlan?
    let onSave: (TradePlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var targetText: String
    @State private var stopText: String

    init(symbol: String, plan: TradePlan?, onSave: @escaping (TradePlan) -> Void) {
        self.symbol = symbol
        self.plan = plan
        self.onSave = onSave
        _targetText = State(initialValue: plan?.target.map { String(format: "%.2f", $0) } ?? "")
        _stopText = State(initialValue: plan?.stop.map { String(format: "%.2f", $0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("\(symbol) plan") {
                    field("Target (take profit)", $targetText)
                    field("Stop / review", $stopText)
                }
                if plan != nil {
                    Section { Button("Clear plan", role: .destructive) { onSave(TradePlan()) } }
                }
            }
            .navigationTitle("Trade Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(TradePlan(target: parse(targetText), stop: parse(stopText))) }
                }
            }
        }
    }

    private func field(_ label: String, _ binding: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("—", text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    private func parse(_ s: String) -> Double? {
        let v = Double(s.trimmingCharacters(in: .whitespaces))
        return (v ?? 0) > 0 ? v : nil
    }
}

/// Sheet: risk-based position sizer.
struct PositionSizerSheet: View {
    let symbol: String
    let entry: Double
    let stop: Double?
    let target: Double?

    @Environment(\.dismiss) private var dismiss
    @State private var accountText: String
    @State private var riskText: String
    @State private var entryText: String
    @State private var stopText: String

    init(symbol: String, entry: Double, stop: Double?, target: Double?) {
        self.symbol = symbol
        self.entry = entry
        self.stop = stop
        self.target = target
        _accountText = State(initialValue: String(format: "%.0f", SettingsStore.shared.accountSize))
        _riskText = State(initialValue: String(format: "%.0f", SettingsStore.shared.maxRiskPerTrade))
        _entryText = State(initialValue: entry > 0 ? String(format: "%.2f", entry) : "")
        _stopText = State(initialValue: stop.map { String(format: "%.2f", $0) } ?? "")
    }

    private var result: PositionSizeResult {
        PositionSizer.size(account: Double(accountText) ?? 0,
                           maxRiskUSD: Double(riskText) ?? 0,
                           entry: Double(entryText) ?? 0,
                           stop: Double(stopText) ?? 0,
                           target: target)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    money("Account size", $accountText)
                    money("Max risk / trade", $riskText)
                }
                Section("\(symbol) trade") {
                    money("Entry", $entryText)
                    money("Stop", $stopText)
                }
                Section("Result") {
                    let r = result
                    row("Shares", "\(r.shares)")
                    row("Position value", Fmt.price(r.positionValue))
                    row("Risk at stop", Fmt.price(r.dollarRisk))
                    if let rr = r.rewardRisk { row("Reward : Risk", String(format: "%.1f : 1", rr)) }
                    if let note = r.note {
                        Text(note).font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Position Sizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveDefaults(); dismiss() }
                }
            }
            .onDisappear { saveDefaults() }
        }
    }

    private func saveDefaults() {
        if let a = Double(accountText), a > 0 { SettingsStore.shared.accountSize = a }
        if let m = Double(riskText), m > 0 { SettingsStore.shared.maxRiskPerTrade = m }
    }

    private func money(_ label: String, _ binding: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).monospacedDigit() }
    }
}

/// Sheet to set a price threshold for a price alert.
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
