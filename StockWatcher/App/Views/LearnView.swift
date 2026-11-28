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

                    // Prominent, important heads-up before the evaluation topics.
                    topicCard(LearnContent.dayTrading)
                    topicCard(LearnContent.caTaxes)

                    ForEach(LearnContent.topics) { topic in
                        topicCard(topic)
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("How this app's rating works", systemImage: "gauge.with.needle")
                                .font(.headline)
                            Text(LocalizedStringKey(LearnContent.ratingExplainer))
                                .font(.subheadline)
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("How Market Mood works", systemImage: "gauge.medium")
                                .font(.headline)
                            Text(LocalizedStringKey(LearnContent.moodExplainer))
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

    @ViewBuilder
    private func topicCard(_ topic: LearnContent.Topic) -> some View {
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
}

enum LearnContent {
    struct Topic: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let points: [String]
    }

    /// Canadian tax heads-up: when the CRA treats trading as a business.
    static let dayTrading = Topic(
        title: "Day trading & the CRA", icon: "exclamationmark.triangle.fill", points: [
        "**There's no fixed \u{201C}day-trader\u{201D} line in Canada.** Unlike the U.S., the CRA has no \u{201C}4 trades in 5 days\u{201D} rule. It decides *case by case* whether your profits are **capital gains** (only half taxable) or **business income** (fully taxable).",
        "**If your activity looks like a *business* of trading, 100% of the gains are taxed** as ordinary income at your marginal rate — not the one-half (50%) capital-gains inclusion (verify the current rate with the CRA). The flip side: genuine trading losses can then offset other income.",
        "**Factors the CRA weighs** — no single one decides; it's the overall picture: high **frequency** of trades, **short holding periods** (days/weeks), lots of **time spent** trading, sophisticated market **knowledge**, use of **margin / borrowed money**, **speculative** holdings (options, penny stocks, non-dividend names), and an intent to **flip for a quick profit** rather than hold or earn income.",
        "**TFSA warning:** a TFSA is **not automatically tax-free.** If the CRA finds you're *carrying on a business* of trading inside it, the profits become **taxable** — the courts upheld this in *Ahamed v. The King*. Frequent, speculative trading is the classic trigger. (RRSPs/RRIFs are **exempt** from this — the law shields business income from *qualified investments* there, which is the very argument the courts refused to extend to TFSAs.)",
        "**Superficial-loss rule:** sell at a loss and buy the same (or an identical) security back within **30 days** — before or after — and the loss is **denied.** It's added to the cost of the new shares instead of being claimed now.",
        "**Keep records.** Track every trade's proceeds, adjusted cost base (ACB) and fees in **Canadian dollars** — the CRA expects you to report them, and \u{201C}I lost track\u{201D} isn't accepted.",
        "**Bottom line:** there's no magic number of trades — it's judgment on the factors above. If you trade actively (*especially inside a TFSA*), read the CRA's **IT-479R \u{201C}Transactions in Securities\u{201D}** and talk to a CPA. This is general information, **not tax advice.**"
    ])

    /// General Canadian tax facts for stock investors. Figures verified for the
    /// 2026 tax year; always point users to the CRA for the current rules.
    static let caTaxes = Topic(
        title: "Taxes & investing (Canada)", icon: "building.columns.fill", points: [
        "**Capital gains:** you're taxed only when you **sell**, not while you hold. For **2026, one-half (50%)** of a gain is taxable at your marginal rate — the proposed rise to 66.7% was cancelled. (Always confirm the current rate with the CRA.)",
        "**Capital losses offset capital gains only** — not your salary or other income. Unused losses carry **back 3 years or forward indefinitely.**",
        "**Adjusted cost base (ACB):** your cost is the **average** across every purchase of the same security, in **Canadian dollars.** Broker T5008 slips often omit it, so tracking ACB is **your** responsibility.",
        "**Dividends depend on source:** **eligible Canadian** dividends get the **dividend tax credit** (a lower effective rate); **foreign** dividends (e.g. U.S.) are taxed as **ordinary income** with no credit and usually have **~15% withheld** at source.",
        "**TFSA:** Canadian gains and dividends are **tax-free** — but **U.S. dividend withholding (~15%) still applies and generally can't be recovered,** and active trading can void the shelter (see above).",
        "**RRSP / RRIF:** grows **tax-deferred**; **U.S. stocks and U.S.-listed ETFs held *directly* are exempt** from the 15% U.S. dividend withholding under the Canada-U.S. treaty. Withdrawals are taxed as income.",
        "**Non-registered:** capital gains and the dividend tax credit apply, and foreign withholding **can** be recovered via the **foreign tax credit.**",
        "**Superficial-loss rule:** rebuy the **same or identical** security within **30 days before or after** a loss sale and the loss is **denied.** In a taxable account it shifts into the new shares' cost (deferred); rebuy it **inside your TFSA/RRSP and the loss is gone for good.**",
        "**Foreign-property reporting (T1135):** if the **total cost** of your foreign property — e.g. U.S. stocks in a **non-registered** account — tops **CAD $100,000** at any point in the year, you must file **Form T1135.** Registered accounts don't count.",
        "**Return of capital (ROC):** some REIT/ETF distributions aren't taxed now but **reduce your ACB** — meaning a **larger taxable gain later.**",
        "**Not tax advice.** Rates and rules change yearly and depend on your situation — confirm with the **CRA** and a **CPA** before filing."
    ])

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
        ]),
        Topic(title: "Chart signals — objective, not patterns", icon: "waveform.path.ecg", points: [
            "**These are rule-based readings from price & volume** — *not* subjective shapes like head-and-shoulders or cup-and-handle (which are noisy and weakly predictive). The detail screen's **Chart Signals** card surfaces them, and none feed the Score.",
            "**Golden / death cross:** the 50-day average crossing **above** (golden, bullish) or **below** (death, bearish) the 200-day — a slow but widely-watched trend signal.",
            "**52-week high / low:** where price sits in its yearly range. New highs show strength, new lows weakness — neither is a buy or sell on its own.",
            "**Trend structure:** higher-highs + higher-lows = uptrend; lower-highs + lower-lows = downtrend; mixed = ranging.",
            "**Support & resistance:** recent swing lows (floors) and highs (ceilings) where price has turned before.",
            "**Volume spikes & gaps:** unusually heavy volume or an opening gap usually marks news — *confirmation* of a move, not a reason on its own."
        ]),
        Topic(title: "Quant checks: what they measure", icon: "function", points: [
            "**Graham Number:** √(22.5 × EPS × book value per share). A conservative ceiling from Benjamin Graham's defensive-investor work. It applies only to profitable companies and ignores growth, so a price above it is not automatically expensive.",
            "**Momentum (≈12-1):** stocks that rose over the past year have tended to keep rising for a while. That is a tendency, not a guarantee. The app shows about 11 months, because its data window is one year, against the TSX Composite.",
            "**Volatility & drawdown:** how far a price typically swings in a year, and how far it has fallen from its high. Know both before sizing a position.",
            "**Return ÷ volatility:** a rough reward-per-risk read. It is not the Sharpe ratio, which also subtracts a risk-free rate.",
            "**Liquidity:** average daily value traded. Thinly traded stocks can be hard to sell at a fair price.",
            "**Sector P/E:** compares valuation with same-sector TSX names. Sectors here are broad, so treat it as context.",
            "**Withholding:** U.S. dividends have about 15% withheld at source. A TFSA generally can't recover it. Held directly in an RRSP, U.S. dividends are generally exempt.",
            "**These are informational.** None is part of the Stock Watcher Score, and none is a buy or sell signal on its own."
        ]),
        Topic(title: "Market mood & fear (VIX)", icon: "gauge.medium", points: [
            "**VIX is the \u{201C}fear gauge\u{201D}** — the S&P 500's expected 30-day volatility priced into options. It rises when investors get nervous and spikes when they panic. For Canada, the equivalent is **VIXC** (S&P/TSX 60).",
            "**Rough levels:** under ~15 calm, 15–20 normal, 20–28 guarded, 28–38 fearful, 38+ panic — the same bands the Ideas tab's Market Mood card uses.",
            "**It's market-wide, not per-stock.** It tells you the weather, not whether one company is a buy.",
            "**Extremes tend to be contrarian:** a very high VIX often marks capitulation near market *bottoms* — usually the worst moment to sell in a panic.",
            "**It's not the only signal.** Also watch the put/call ratio, the CNN Fear & Greed Index, widening credit spreads, weak market breadth, and money fleeing into gold and bonds."
        ])
    ]

    static let ratingExplainer = """
    The **buy/sell gauge** aggregates 11 oscillators (RSI, MACD, Stochastic, CCI, ADX and more) and up to 15 moving averages into a single reading — the same methodology TradingView uses. Each indicator votes Buy, Sell or Neutral; the votes are averaged and bucketed into **Strong Sell → Strong Buy**.

    It is a **momentum/trend signal computed from price only**. It does *not* read the balance sheet. Pair it with the **Fundamentals** section and the checklist above before acting.
    """

    static let moodExplainer = """
    The **Market Mood** card (Ideas tab) and the widget header read **VIX** — and **VIXC** for the TSX when available — and map it to a calm → panic band. Green means low fear or complacency; red means panic.

    Treat it as *context, not a trigger*: it frames how stressed the whole market is, which can inform position sizing and whether to wait for calmer conditions. A falling VIX (shown in green) means fear is easing; a rising one means it's building.
    """

    static let disclaimer = """
    Educational content only — not financial or investment advice. Investing involves risk, including loss of principal. Do your own research and consider a licensed advisor.
    """
}
