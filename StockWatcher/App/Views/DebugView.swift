import SwiftUI
import UIKit

struct DebugView: View {
    @State private var testing = false
    @State private var testOutput: String?

    private var appGroupActive: Bool { DataCache.shared.appGroupAvailable }

    var body: some View {
        Form {
            Section {
                HStack {
                    Label("Widget data sharing", systemImage: appGroupActive ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(appGroupActive ? .green : .orange)
                    Spacer()
                    Text(appGroupActive ? "Active" : "Not shared")
                        .foregroundStyle(.secondary)
                }
                Text(appGroupActive
                     ? "The App Group is provisioned, so the widget shows your watchlist."
                     : "The App Group isn’t provisioned (common on sideloaded builds). The app works fully; the widget falls back to a default TSX list. In Sideloadly, keep the App Groups option enabled.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: {
                Text("App Group")
            }

            Section("Watchlist") {
                let items = WatchlistStore.shared.load()
                HStack { Text("Symbols"); Spacer(); Text("\(items.count)").foregroundStyle(.secondary) }
                Text(items.map(\.symbol).joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Cache") {
                HStack { Text("Location"); Spacer(); Text(DataCache.shared.locationDescription).font(.caption).foregroundStyle(.secondary) }
                HStack { Text("Files"); Spacer(); Text("\(DataCache.shared.fileCount())").foregroundStyle(.secondary) }
            }

            Section("Connectivity test") {
                Button {
                    Task { await runTest() }
                } label: {
                    HStack {
                        Text("Test Yahoo Finance")
                        Spacer()
                        if testing { ProgressView() }
                    }
                }
                .disabled(testing)
                if let out = testOutput {
                    Text(out).font(.caption.monospaced()).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section("Environment") {
                row("App version", SettingsView.versionString)
                row("iOS", UIDevice.current.systemVersion)
                row("Device", UIDevice.current.model)
                row("Refresh interval", "\(SettingsStore.shared.refreshMinutes) min")
                row("Default range", SettingsStore.shared.defaultRange.label)
            }
        }
        .navigationTitle("App Debug")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary) }
    }

    private func runTest() async {
        testing = true
        testOutput = nil
        defer { testing = false }
        var lines: [String] = []
        let start = Date()

        do {
            let q = try await YahooService.shared.fetchQuote(symbol: "RY.TO")
            lines.append("RY.TO  \(Fmt.price(q.price)) \(q.currency ?? "")  ✓")
        } catch {
            lines.append("RY.TO  FAILED — \(error.localizedDescription)")
        }

        if let vix = try? await YahooService.shared.fetchQuote(symbol: "^VIX") {
            lines.append("^VIX   \(Fmt.number(vix.price, decimals: 1))  ✓")
        } else {
            lines.append("^VIX   unavailable")
        }

        let f = await YahooService.shared.fetchFundamentals(symbol: "RY.TO")
        lines.append("Fundamentals: \(f.isEmpty ? "unavailable (crumb/throttled)" : "ok")")

        lines.append(String(format: "elapsed %.1fs", Date().timeIntervalSince(start)))
        testOutput = lines.joined(separator: "\n")
    }
}

#Preview {
    NavigationStack { DebugView() }
}
