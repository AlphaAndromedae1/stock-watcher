# Stock Watcher

An iOS 17 app that gives a **TradingView‑style buy / sell evaluation** for a stock
(with a focus on the **Toronto Stock Exchange**) plus a **lightweight home‑ and
lock‑screen widget** for tracking your watchlist at a glance.

- **Technical rating** — 11 oscillators + up to 15 moving averages aggregated into
  **Strong Sell → Strong Buy**, the same methodology TradingView's "Technicals" uses.
- **Stock Watcher Score** — a custom 0–100 composite blending technicals, fundamentals,
  analyst consensus and target upside, shown on the detail screen *and* in the widget.
- **Ideas tab** — scans the TSX catalog and surfaces algorithmic **Recommended Buys**,
  ranked best-first.
- **Market Mood** — a VIX / VIXC (TSX) "fear gauge" read with a calm→panic band, on the
  Ideas tab and in the widget header.
- **Price chart** with selectable ranges (1D–5Y) via Swift Charts.
- **Fundamentals** (best‑effort) — P/E, PEG, margins, ROE, debt, growth, dividend,
  beta, 52‑week range, analyst consensus and mean target — with plain‑English checks.
- **Learn tab** — "what matters most when buying a stock", built into the app.
- **WidgetKit widget** — small / medium / large + a lock‑screen accessory, sharing
  the same watchlist as the app through an App Group.
- **Free data** from Yahoo Finance. No API key, no account, no third‑party SDKs.

> ⚠️ **Not financial advice.** Ratings are algorithmic signals derived from price
> data. Data is delayed. Always do your own research.

---

## Requirements

- macOS with **Xcode 15+** (iOS 17 SDK)
- **[XcodeGen](https://github.com/yonbergman/xcodegen)** (`brew install xcodegen`) —
  the `.xcodeproj` is generated from [`StockWatcher/project.yml`](StockWatcher/project.yml),
  not committed, so targets/entitlements stay clean and mergeable.

## Build & run

```bash
./scripts/bootstrap.sh
```

That installs XcodeGen if needed, generates `StockWatcher/StockWatcher.xcodeproj`,
and opens it. Then in Xcode pick the **StockWatcher** scheme and an iPhone
simulator (or your device) and press **Run**.

Or manually:

```bash
cd StockWatcher
xcodegen generate
open StockWatcher.xcodeproj
```

### Signing (required only for a real device / TestFlight / IPA)

The app and widget share a watchlist through the App Group
`group.com.stockwatcher.app`. On the **Simulator** it runs as‑is. For a **device**:

1. Open the project, select the **StockWatcher** target → **Signing & Capabilities**,
   choose your Team. Do the same for **StockWidgetExtension**.
2. Either keep the bundle IDs (`com.stockwatcher.app` / `.app.StockWidget`) or change
   the prefix in `project.yml`. If you change the App Group ID, update it in **all
   three** places: `project.yml` reference, both `*.entitlements` files, and
   `WatchlistStore.appGroupID`.
3. Set `DEVELOPMENT_TEAM` in `project.yml` (or just use the Xcode Signing tab) and
   re‑run `xcodegen generate`.

### Building an IPA

- **CI:** [`.github/workflows/ios.yml`](.github/workflows/ios.yml) builds and tests on
  every push. It includes a disabled `archive-ipa` job — add your App Store Connect /
  signing secrets and flip its `if:` to produce an `.ipa` artifact.
- **Locally:** Xcode → **Product ▸ Archive**, then distribute. A sample
  `ExportOptions` plist is in `scripts/`.

## Running the tests

The analysis engine has unit tests (pure, no network). In Xcode press **⌘U**, or:

```bash
cd StockWatcher
xcodebuild -scheme StockWatcher \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  CODE_SIGNING_ALLOWED=NO test
```

## Using the widget

Long‑press the home screen → **+** → search **Stock Watcher** → pick a size. It shows
the top of your watchlist (small = 2, medium = 4, large = 8) and refreshes about every
30 minutes. Add/remove/reorder stocks in the app and the widget follows.

---

## Project layout

```
StockWatcher/
  project.yml                 XcodeGen spec (source of truth for targets)
  App/                        SwiftUI app (watchlist, detail/rating, search, learn)
  Widget/                     WidgetKit extension (home + lock screen)
  Shared/                     Code compiled into both targets:
    Models/                     Candle, Quote, Fundamentals, WatchItem, TechnicalRating
    Networking/                 YahooService + Codable DTOs
    Analysis/                   Indicators (pure math) + TechnicalAnalyzer + FundamentalAnalyzer
    Store/                      WatchlistStore (App Group UserDefaults)
    TSX/                        Curated TSX symbol catalog for search
    Util/                       Formatters
  Tests/                      Unit tests for the analysis engine
scripts/                      bootstrap.sh, make_icon.py, ExportOptions sample
.github/workflows/ios.yml     CI: generate + build + test
```

## How the rating is computed

On ~1 year of **daily** candles, each indicator casts a vote
(Buy `+1` / Neutral `0` / Sell `-1`) using TradingView's rules:

- **Oscillators (11):** RSI, Stochastic %K, CCI, ADX (+DI/−DI), Awesome Oscillator,
  Momentum, MACD, Stochastic RSI, Williams %R, Ultimate Oscillator, Bull Bear Power.
- **Moving Averages (≤15):** SMA & EMA (10/20/30/50/100/200), Ichimoku Base Line,
  VWMA(20), Hull MA(9).

Votes are averaged per group and overall, then bucketed:
`avg ≥ 0.5` Strong Buy · `≥ 0.1` Buy · `> −0.1` Neutral · `> −0.5` Sell · else Strong Sell.
Indicators that can't be computed from the available history are skipped, not counted.

## Data source & limitations

- Prices/history come from Yahoo Finance's public `chart` endpoint — stable, key‑less,
  and the backbone of the app and widget. Quotes are **delayed**.
- Fundamentals come from Yahoo's `quoteSummary` endpoint, which is cookie/"crumb"‑gated
  and sometimes rate‑limited. It's **best‑effort**: if it's unavailable the app hides
  the section and the technical rating is unaffected.
- TSX tickers use Yahoo's convention: `.TO` (TSX) and `.V` (TSX Venture), e.g. `RY.TO`,
  `SHOP.TO`. You can also type any Yahoo symbol in Search.

## What matters most when buying a stock

A short version of the in‑app **Learn** tab:

1. **Understand the business** — what it sells, how it earns, and its durable advantage.
2. **Valuation** — P/E, PEG, P/B vs. the company's history *and* peers. A great company
   at a bad price is a bad investment.
3. **Financial health** — manageable debt, strong free cash flow, no constant dilution.
4. **Profitability & returns** — margins and ROE/ROIC that are high and improving.
5. **Growth** — multi‑year, profitable, organic revenue/earnings growth.
6. **Dividends** — attractive yield *with a sustainable payout ratio*; a track record of raises.
7. **Risk & sizing** — diversify, know the volatility (beta), define your thesis and exit.
8. **Timing/technicals** — use trend/RSI/MACD (this app's gauge) for *entry timing*, as a
   tiebreaker — not as the reason to own a business.

---

*Built with Claude Code.*
