import SwiftUI

struct SearchView: View {
    /// When provided (sheet mode), tapping a row adds it and dismisses.
    /// When nil (tab mode), tapping navigates to the detail screen.
    var onPick: ((TSXCatalog.Entry) -> Void)? = nil

    @State private var query = ""
    @State private var remote: [TSXCatalog.Entry] = []
    @State private var isSearching = false

    /// Offline catalog matches first, then live Yahoo hits (deduped), so a typed
    /// ticker or keyword autocompletes across every exchange — not just the TSX.
    private var merged: [TSXCatalog.Entry] {
        let local = TSXCatalog.search(query)
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return local }
        var seen = Set(local.map { $0.symbol.uppercased() })
        var out = local
        for e in remote where !seen.contains(e.symbol.uppercased()) {
            out.append(e)
            seen.insert(e.symbol.uppercased())
        }
        return out
    }

    /// Offline fallback: if nothing matched (e.g. no network), still let the user
    /// force a raw Yahoo symbol, plus a ".TO" TSX guess.
    private var fallbackEntries: [TSXCatalog.Entry] {
        let raw = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard raw.count >= 1, merged.isEmpty, !isSearching else { return [] }
        var out = [TSXCatalog.Entry(symbol: raw, name: "Look up “\(raw)”", sector: "Custom")]
        if !raw.contains(".") {
            out.append(.init(symbol: raw + ".TO", name: "Look up “\(raw).TO” (TSX)", sector: "Custom"))
        }
        return out
    }

    var body: some View {
        List {
            if !fallbackEntries.isEmpty {
                Section("Look up") { ForEach(fallbackEntries) { row($0) } }
            }
            Section {
                ForEach(merged) { row($0) }
            } header: {
                HStack {
                    Text(query.isEmpty ? "Popular TSX stocks" : "Matches")
                    if isSearching {
                        ProgressView().controlSize(.mini).padding(.leading, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Symbol or company (e.g. SHOP, Royal Bank, AAPL)")
        .autocorrectionDisabled()
        .task(id: query) { await liveSearch() }
    }

    /// Debounced live lookup. `.task(id:)` cancels & restarts on each keystroke,
    /// so the sleep both debounces and avoids a request per character.
    private func liveSearch() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { remote = []; isSearching = false; return }
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }
        isSearching = true
        let hits = await YahooService.shared.searchSymbols(query: q)
        guard !Task.isCancelled else { return }
        remote = hits
        isSearching = false
    }

    @ViewBuilder
    private func row(_ entry: TSXCatalog.Entry) -> some View {
        if let onPick {
            Button { onPick(resolved(entry)) } label: {
                HStack {
                    entryLabel(entry)
                    Spacer()
                    Image(systemName: "plus.circle.fill").foregroundStyle(.tint)
                }
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                StockDetailView(symbol: entry.symbol, name: resolved(entry).name)
            } label: {
                entryLabel(entry)
            }
        }
    }

    private func entryLabel(_ entry: TSXCatalog.Entry) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.symbol.replacingOccurrences(of: ".TO", with: "")
                                 .replacingOccurrences(of: ".V", with: ""))
                    .font(.headline)
                Text(entry.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if let tag = exchangeTag(entry) {
                Text(tag)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    private func exchangeTag(_ entry: TSXCatalog.Entry) -> String? {
        let s = entry.symbol.uppercased()
        if s.hasSuffix(".TO") { return "TSX" }
        if s.hasSuffix(".V") { return "TSXV" }
        let sectors: Set<String> = ["Financials", "Energy", "Materials", "Technology",
                                    "Industrials", "Communication", "Consumer", "Utilities",
                                    "Real Estate", "Healthcare", "Custom"]
        return (!entry.sector.isEmpty && !sectors.contains(entry.sector)) ? entry.sector : nil
    }

    /// For a typed-in ("Custom") symbol, replace the "Look up …" prompt with a
    /// real name if we know it, otherwise the bare symbol.
    private func resolved(_ entry: TSXCatalog.Entry) -> TSXCatalog.Entry {
        guard entry.sector == "Custom" else { return entry }
        let name = TSXCatalog.name(for: entry.symbol)
            ?? entry.symbol.replacingOccurrences(of: ".TO", with: "").replacingOccurrences(of: ".V", with: "")
        return .init(symbol: entry.symbol, name: name, sector: "Custom")
    }
}

#Preview {
    NavigationStack { SearchView().navigationTitle("Search") }
}
