import SwiftUI

struct WatchlistView: View {
    @StateObject private var model = WatchlistViewModel()
    @ObservedObject var router: DeepLinkRouter
    @State private var showingSearch = false

    var body: some View {
        NavigationStack {
            Group {
                if model.items.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationDestination(item: $router.target) { link in
                StockDetailView(symbol: link.symbol, name: link.name)
            }
            .navigationTitle("TSX Watchlist")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !model.items.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSearch = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingSearch) {
                NavigationStack {
                    SearchView(onPick: { entry in
                        model.add(WatchItem(symbol: entry.symbol, name: entry.name))
                        showingSearch = false
                    })
                    .navigationTitle("Add Symbol")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showingSearch = false }
                        }
                    }
                }
            }
        }
        .task { model.onAppear() }
        .refreshable { await model.refresh() }
    }

    private var list: some View {
        List {
            if let p = model.portfolio {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Portfolio").font(.subheadline.weight(.semibold))
                            Text("\(p.count) holding\(p.count == 1 ? "" : "s")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Fmt.price(p.marketValue))
                                .font(.headline.monospacedDigit())
                            Text("\(Fmt.signedMoney(p.gain)) (\(Fmt.signedPercent(p.gainPercent)))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.forChange(p.gain >= 0))
                        }
                    }
                }
            }
            Section {
                ForEach(model.items) { item in
                    NavigationLink {
                        StockDetailView(symbol: item.symbol, name: item.name)
                    } label: {
                        QuoteRow(item: item, quote: model.quotes[item.symbol],
                                 spark: model.sparks[item.symbol] ?? [])
                    }
                }
                .onDelete(perform: model.remove(atOffsets:))
                .onMove(perform: model.move(from:to:))
            } footer: {
                if let updated = model.lastUpdated {
                    Text("Updated \(Fmt.time(updated)) • Data: Yahoo Finance, delayed")
                        .font(.caption2)
                }
            }
        }
        .listStyle(.plain)
        .overlay(alignment: .top) {
            if model.isLoading && model.quotes.isEmpty {
                ProgressView().padding(.top, 40)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No stocks yet", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text("Add TSX-listed stocks to track their price and get a buy/sell rating.")
        } actions: {
            Button("Add a stock") { showingSearch = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

/// A single watchlist row: name + symbol on the left, price + change on the right.
struct QuoteRow: View {
    let item: WatchItem
    let quote: Quote?
    var spark: [Double] = []

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(symbolDisplay)
                    .font(.headline)
                Text(item.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if let q = quote {
                if spark.count > 1 {
                    MiniSparkline(values: spark, up: q.isUp)
                        .frame(width: 56, height: 28)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Fmt.price(q.price))
                        .font(.headline.monospacedDigit())
                    HStack(spacing: 4) {
                        Image(systemName: q.isUp ? "arrow.up" : "arrow.down")
                            .font(.caption2.bold())
                        Text(Fmt.signedPercent(q.changePercent))
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(Color.forChange(q.isUp))
                    if let h = HoldingsStore.shared.holding(symbol: item.symbol) {
                        Text("P/L \(Fmt.signedPercent(h.gainPercent(at: q.price)))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.forChange(h.gain(at: q.price) >= 0))
                    }
                }
            } else {
                ProgressView()
            }
        }
        .padding(.vertical, 4)
    }

    private var symbolDisplay: String {
        item.symbol.replacingOccurrences(of: ".TO", with: "")
            .replacingOccurrences(of: ".V", with: "")
    }
}

#Preview {
    WatchlistView(router: DeepLinkRouter())
}
