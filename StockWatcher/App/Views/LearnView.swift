import SwiftUI

struct LearnView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Before you buy a stock, you're really asking two questions: *is this a good business*, and *is this a good price*. These are the things that matter most, roughly in order.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    ForEach(LearnContent.topics) { topic in
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(topic.title, systemImage: topic.icon)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                ForEach(topic.points, id: \.self) { point in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•").foregroundStyle(.tint)
                                        Text(LocalizedStringKey(point)).font(.subheadline)
                                    }
                                }
                            }
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("How this app's rating works", systemImage: "gauge.with.needle")
                                .font(.headline)
                            Text(LocalizedStringKey(LearnContent.ratingExplainer))
                                .font(.subheadline)
                        }
                    }

                    Text(LearnContent.disclaimer)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding()
            }
            .navigationTitle("Learn")
        }
    }
}

enum LearnContent {
    struct Topic: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let points: [String]
    }

    static let topics: [Topic] = [
        Topic(title: "Understand the business", icon: "building.2.fill", points: [
            "**What does the company actually sell, and how does it make money?** If you can't explain it simply, that's a red flag.",
            "**Durable advantage (moat):** brand, scale, network effects, switching costs, or low-cost production that keeps competitors out.",
            "**Industry & cycle:** banks, energy and miners (much of the TSX) move with interest rates and commodity prices — know what drives the sector."
        ]),
        Topic(title: "Valuation — is the price reasonable?", icon: "tag.fill", points: [
            "**P/E ratio:** price relative to earnings. Compare it to the company's own history *and* to peers — a '20' means little without context.",
            "**PEG ratio:** P/E adjusted for growth. Around 1 or below can signal growth isn't fully priced in.",
            "**Price/Book & Price/Sales:** useful for banks, insurers and unprofitable growth names where P/E breaks down.",
            "**A great company at a bad price is a bad investment.** Valuation is how you avoid overpaying."
        ]),
        Topic(title: "Financial health", icon: "heart.text.square.fill", points: [
            "**Debt:** check debt-to-equity and whether earnings comfortably cover interest. High debt is dangerous when rates rise.",
            "**Cash flow:** free cash flow matters more than headline earnings — it's harder to fake.",
            "**Liquidity:** can it fund operations without constantly raising money or diluting shareholders?"
        ]),
        Topic(title: "Profitability & returns", icon: "percent", points: [
            "**Margins:** higher and stable net/operating margins signal pricing power and efficiency.",
            "**Return on equity (ROE) / invested capital (ROIC):** how well management turns capital into profit. Consistently >10–15% is strong.",
            "**Trend matters:** are margins and returns improving or deteriorating over several years?"
        ]),
        Topic(title: "Growth", icon: "chart.line.uptrend.xyaxis", points: [
            "**Revenue and earnings growth** over multiple years, not one quarter.",
            "**Quality of growth:** organic and profitable beats growth bought with debt or endless share issuance.",
            "**Runway:** is the market still expanding, or is the company fighting for a shrinking pie?"
        ]),
        Topic(title: "Dividends & shareholder returns", icon: "dollarsign.circle.fill", points: [
            "**Yield** is attractive (many TSX blue chips pay well), but check the **payout ratio** — a yield funded by debt isn't safe.",
            "**Track record:** a long history of maintaining/raising the dividend signals discipline.",
            "**Buybacks** can boost per-share value when done at sensible prices."
        ]),
        Topic(title: "Risk & position sizing", icon: "shield.lefthalf.filled", points: [
            "**Diversify:** don't let one stock or one sector dominate your portfolio.",
            "**Volatility (beta):** know how much the stock swings versus the market before you size a position.",
            "**Know your thesis and your exit:** write down why you're buying and what would make you sell.",
            "**Time horizon & currency:** TSX stocks trade in CAD — consider FX if you think in USD."
        ]),
        Topic(title: "Timing & sentiment (secondary)", icon: "clock.fill", points: [
            "**Technicals** (trend, moving averages, RSI/MACD) help with *entry timing* — they don't tell you if the business is good.",
            "**Use them as a tiebreaker,** not the whole decision. This app's buy/sell gauge is a technical signal.",
            "**Beware the news cycle:** price already reflects what everyone knows. Edge comes from a differentiated, well-reasoned view."
        ])
    ]

    static let ratingExplainer = """
    The **buy/sell gauge** aggregates 11 oscillators (RSI, MACD, Stochastic, CCI, ADX and more) and up to 15 moving averages into a single reading — the same methodology TradingView uses. Each indicator votes Buy, Sell or Neutral; the votes are averaged and bucketed into **Strong Sell → Strong Buy**.

    It is a **momentum/trend signal computed from price only**. It does *not* read the balance sheet. Pair it with the **Fundamentals** section and the checklist above before acting.
    """

    static let disclaimer = """
    Educational content only — not financial or investment advice. Investing involves risk, including loss of principal. Do your own research and consider a licensed advisor.
    """
}
