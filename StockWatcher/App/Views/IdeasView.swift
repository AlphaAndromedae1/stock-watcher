import SwiftUI
import UIKit

struct IdeasView: View {
    @StateObject private var model = IdeasViewModel()
    @StateObject private var magic = MagicFormulaViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !model.overview.isEmpty {
                        overviewStrip
                    }
                    if let mood = model.mood {
                        MarketMoodCard(mood: mood)
                    }
                    recommendedCard
                    MagicFormulaCard(model: magic)
                    disclaimer
                }
                .padding()
            }
            .navigationTitle("Ideas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.isLoading)
                }
            }
        }
        .task {
            model.onAppear()
            magic.onAppear()
        }
        .refreshable { await model.refresh() }
    }

    private var overviewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(model.overview) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.caption2).foregroundStyle(.secondary)
                        Text(Fmt.number(item.quote.price, decimals: item.quote.price > 1000 ? 0 : 2))
                            .font(.subheadline.bold().monospacedDigit())
                        Text(Fmt.signedPercent(item.quote.changePercent))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.forChange(item.quote.isUp))
                    }
                    .frame(minWidth: 72, alignment: .leading)
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var recommendedCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Recommended Buys", systemImage: "sparkles")
                        .font(.headline)
                    Spacer()
                    if !model.recommendedBuys.isEmpty {
                        Text("\(model.recommendedBuys.count)")
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }
                }

                if model.isLoading && model.ideas.isEmpty {
                    VStack(spacing: 8) {
                        ProgressView(value: model.progress)
                        Text("Analyzing \(TSXCatalog.all.count) TSX stocks… \(Int(model.progress * 100))%")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else if model.recommendedBuys.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No buy-rated TSX names right now.")
                            .font(.subheadline.weight(.medium))
                        Text("The technical trend is weak across the board — often a cautious or falling market. Check back, or pull to refresh.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Highest technical ratings across the TSX right now, best first.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(model.recommendedBuys.enumerated()), id: \.element.id) { index, idea in
                        NavigationLink {
                            StockDetailView(symbol: idea.entry.symbol, name: idea.entry.name)
                        } label: {
                            ideaRow(idea)
                        }
                        .buttonStyle(.plain)
                        if index < model.recommendedBuys.count - 1 {
                            Divider().opacity(0.4)
                        }
                    }
                }

                if let updated = model.lastUpdated {
                    Text("Updated \(Fmt.time(updated))")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func ideaRow(_ idea: IdeasViewModel.Idea) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(idea.entry.symbol.replacingOccurrences(of: ".TO", with: "")
                    .replacingOccurrences(of: ".V", with: ""))
                    .font(.headline)
                Text(idea.entry.name)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if !idea.setups.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(idea.setups, id: \.self) { s in
                            Text(s.rawValue)
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(.quaternary, in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 4)
            if let q = idea.quote {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Fmt.price(q.price)).font(.subheadline.monospacedDigit())
                    Text(Fmt.signedPercent(q.changePercent))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color.forChange(q.isUp))
                }
            }
            recommendationPill(idea.recommendation)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    private func recommendationPill(_ rec: Recommendation) -> some View {
        Text(rec.label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(rec.color, in: Capsule())
            .fixedSize()
    }

    private var disclaimer: some View {
        Text("“Recommended” means a strong algorithmic technical rating — momentum/trend only, not a fundamental or advice-based recommendation. Data from Yahoo Finance, delayed. Always do your own research.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
}

struct MarketMoodCard: View {
    let mood: MarketMood

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Market Mood", systemImage: "gauge.medium")
                        .font(.headline)
                    Spacer()
                    if let band = mood.band {
                        Text(band.label)
                            .font(.subheadline.bold())
                            .foregroundStyle(band.color)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    if let v = mood.headline {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(mood.headlineName) · Fear gauge")
                                .font(.caption2).foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(Fmt.number(v, decimals: 1))
                                    .font(.largeTitle.bold().monospacedDigit())
                                if let ch = mood.vixChangePercent, mood.vix != nil {
                                    Text(Fmt.signedPercent(ch))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(Color.forChange(ch <= 0)) // VIX down = calmer
                                }
                            }
                        }
                    }
                    Spacer()
                    if let vixc = mood.vixc, mood.vix != nil {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("VIXC · TSX").font(.caption2).foregroundStyle(.secondary)
                            Text(Fmt.number(vixc, decimals: 1)).font(.headline.monospacedDigit())
                        }
                    }
                }

                scale

                if let band = mood.band {
                    Text(band.guidance).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var scale: some View {
        HStack(spacing: 4) {
            ForEach(MarketMood.Band.allCases, id: \.rawValue) { b in
                Capsule()
                    .fill(b == mood.band ? b.color : b.color.opacity(0.22))
                    .frame(height: b == mood.band ? 9 : 6)
            }
        }
    }
}

#Preview {
    IdeasView()
}
