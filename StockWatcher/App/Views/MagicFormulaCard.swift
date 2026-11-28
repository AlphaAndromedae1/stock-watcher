import SwiftUI

/// The Magic Formula ranking of the TSX universe, run on the phone and cached for a day.
struct MagicFormulaCard: View {
    @ObservedObject var model: MagicFormulaViewModel

    private static let topCount = 20

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                header
                if model.isRunning {
                    runningView
                } else if let ranking = model.ranking {
                    rankingView(ranking)
                } else {
                    introView
                }
                disclaimer
            }
        }
    }

    private var header: some View {
        HStack {
            Label("Magic Formula · TSX", systemImage: "wand.and.stars")
                .font(.headline)
            Spacer()
            if let ranking = model.ranking {
                Text("\(ranking.rows.count) ranked")
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    private var runningView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: model.progress)
            Text("Ranking \(MagicFormula.universe.count) TSX names… \(Int(model.progress * 100))%")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var introView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ranks the \(MagicFormula.universe.count) non-financial TSX names by earnings yield and return on capital, using annual statements and today's price. It runs on your phone, takes under a minute, and keeps results for a day.")
                .font(.caption).foregroundStyle(.secondary)
            Button {
                Task { await model.run() }
            } label: {
                Label("Run ranking", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func rankingView(_ ranking: MagicRanking) -> some View {
        let top = Array(ranking.rows.prefix(Self.topCount))
        return VStack(alignment: .leading, spacing: 10) {
            Text("Top \(top.count), best first. The combined rank adds the earnings-yield rank and the return-on-capital rank.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(Array(top.enumerated()), id: \.element.id) { index, row in
                NavigationLink {
                    StockDetailView(symbol: row.symbol, name: row.name)
                } label: {
                    rankRow(row)
                }
                .buttonStyle(.plain)
                if index < top.count - 1 {
                    Divider().opacity(0.4)
                }
            }
            footer(ranking)
            Button {
                Task { await model.run() }
            } label: {
                Label("Run again", systemImage: "arrow.clockwise")
            }
            .font(.subheadline)
        }
    }

    private func rankRow(_ row: MagicRow) -> some View {
        HStack(spacing: 10) {
            Text("\(row.rank)")
                .font(.subheadline.bold().monospacedDigit())
                .frame(width: 26, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(displaySymbol(row.symbol))
                    .font(.headline)
                Text(row.name)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text("Yield \(Fmt.percentFromFraction(row.earningsYield, decimals: 1))")
                    .font(.caption.monospacedDigit())
                Text("Return \(Fmt.percentFromFraction(row.returnOnCapital, decimals: 0))")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    private func footer(_ ranking: MagicRanking) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Updated \(Fmt.time(ranking.savedAt)) · \(ranking.excluded.count) of \(ranking.universeSize) excluded")
                .font(.caption2).foregroundStyle(.tertiary)
            if !ranking.excluded.isEmpty {
                DisclosureGroup("Why some names are excluded") {
                    ForEach(ranking.excluded) { item in
                        HStack(alignment: .top) {
                            Text(displaySymbol(item.symbol))
                                .font(.caption.bold())
                                .frame(width: 56, alignment: .leading)
                            Text(item.reason)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .font(.caption)
            }
        }
    }

    private var disclaimer: some View {
        Text("Magic Formula ranks cheap, productive companies as a screen, not advice, and it isn't part of the Stock Watcher Score. Greenblatt tested it on U.S. large caps, so treat a TSX ranking as a starting point.")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private func displaySymbol(_ symbol: String) -> String {
        symbol.replacingOccurrences(of: ".TO", with: "").replacingOccurrences(of: ".V", with: "")
    }
}
