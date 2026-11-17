import SwiftUI

struct WatchlistView: View {
    @StateObject private var model = WatchlistViewModel()
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
            Section {
                ForEach(model.items) { item in
                    NavigationLink {
                        StockDetailView(symbol: item.symbol, name: item.name)
                    } label: {
                        QuoteRow(item: item, quote: model.quotes[item.symbol])
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
            Spacer()
            if let q = quote {
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
    WatchlistView()
}
