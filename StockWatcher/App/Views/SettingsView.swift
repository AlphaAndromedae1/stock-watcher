import SwiftUI

struct SettingsView: View {
    private let store = SettingsStore.shared

    @State private var refreshMinutes = SettingsStore.shared.refreshMinutes
    @State private var defaultRange = SettingsStore.shared.defaultRange
    @State private var wTechnical = SettingsStore.shared.weights.technical
    @State private var wFundamental = SettingsStore.shared.weights.fundamental
    @State private var wAnalyst = SettingsStore.shared.weights.analyst
    @State private var wTarget = SettingsStore.shared.weights.target
    @State private var showClearedAlert = false

    private var weightTotal: Double { max(wTechnical + wFundamental + wAnalyst + wTarget, 0.0001) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Data") {
                    Picker("Widget refresh", selection: $refreshMinutes) {
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                    }
                    .onChange(of: refreshMinutes) { _, v in store.refreshMinutes = v }

                    Picker("Default chart range", selection: $defaultRange) {
                        ForEach(ChartRange.allCases, id: \.self) { r in
                            Text(r.label).tag(r)
                        }
                    }
                    .onChange(of: defaultRange) { _, v in store.defaultRange = v }
                }

                Section {
                    weightRow("Technicals", value: $wTechnical)
                    weightRow("Fundamentals", value: $wFundamental)
                    weightRow("Analyst consensus", value: $wAnalyst)
                    weightRow("Analyst target", value: $wTarget)
                    Button("Reset to defaults") { resetWeights() }
                        .font(.subheadline)
                } header: {
                    Text("Stock Watcher Score weights")
                } footer: {
                    Text("How much each signal counts toward the 0–100 score. Shown as the normalized share.")
                }

                Section("Cache") {
                    HStack {
                        Text("Storage")
                        Spacer()
                        Text(DataCache.shared.locationDescription)
                            .foregroundStyle(.secondary).font(.caption)
                    }
                    HStack {
                        Text("Cached files")
                        Spacer()
                        Text("\(DataCache.shared.fileCount())").foregroundStyle(.secondary)
                    }
                    Button("Clear cache") {
                        DataCache.shared.clearAll()
                        showClearedAlert = true
                    }
                }

                Section {
                    NavigationLink {
                        DebugView()
                    } label: {
                        Label("App Debug", systemImage: "ladybug.fill")
                    }
                } footer: {
                    Text("Diagnostics for data, App Group sharing and connectivity.")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Self.versionString).foregroundStyle(.secondary)
                    }
                    Text("Data from Yahoo Finance, delayed. Research/education only — not financial advice.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .alert("Cache cleared", isPresented: $showClearedAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func weightRow(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(Int((value.wrappedValue / weightTotal) * 100))%")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...1, step: 0.05)
                .onChange(of: value.wrappedValue) { _, _ in saveWeights() }
        }
    }

    private func saveWeights() {
        store.weights = CompositeEvaluator.Weights(
            technical: wTechnical, fundamental: wFundamental,
            analyst: wAnalyst, target: wTarget)
    }

    private func resetWeights() {
        let d = CompositeEvaluator.Weights.default
        wTechnical = d.technical; wFundamental = d.fundamental
        wAnalyst = d.analyst; wTarget = d.target
        store.weights = d
    }

    static var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

#Preview {
    SettingsView()
}
