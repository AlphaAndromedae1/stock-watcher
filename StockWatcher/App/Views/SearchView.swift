import SwiftUI

struct SearchView: View {
    /// When provided (sheet mode), tapping a row adds it and dismisses.
    /// When nil (tab mode), tapping navigates to the detail screen.
    var onPick: ((TSXCatalog.Entry) -> Void)? = nil

    @State private var query = ""

    private var results: [TSXCatalog.Entry] {
        TSXCatalog.search(query)
    }

    /// If the user types something not in the catalog, offer to look it up as a
    /// raw Yahoo symbol (and a ".TO" TSX guess when there's no suffix).
    private var customEntries: [TSXCatalog.Entry] {
        let raw = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard raw.count >= 1 else { return [] }
        var out: [TSXCatalog.Entry] = []
        let known = Set(results.map(\.symbol))
        if !known.contains(raw) {
            out.append(.init(symbol: raw, name: "Look up “\(raw)”", sector: "Custom"))
        }
        if !raw.contains("."), !known.contains(raw + ".TO") {
            out.append(.init(symbol: raw + ".TO", name: "Look up “\(raw).TO” (TSX)", sector: "Custom"))
        }
        return out
    }

    var body: some View {
        List {
            if !customEntries.isEmpty {
                Section("Look up") {
                    ForEach(customEntries) { row($0) }
                }
            }
            Section(query.isEmpty ? "Popular TSX stocks" : "Matches") {
                ForEach(results) { row($0) }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Symbol or company (e.g. SHOP, Royal Bank)")
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
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
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.symbol.replacingOccurrences(of: ".TO", with: ""))
                .font(.headline)
            Text(entry.name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
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
