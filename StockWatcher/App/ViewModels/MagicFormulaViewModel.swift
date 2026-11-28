import Foundation
import Combine

/// Shows the Magic Formula ranking and runs it on request. Results are cached for a
/// day, and a run only starts when the user asks for one.
@MainActor
final class MagicFormulaViewModel: ObservableObject {
    @Published private(set) var ranking: MagicRanking?
    @Published private(set) var isRunning = false
    @Published private(set) var progress: Double = 0

    func onAppear() {
        if ranking == nil {
            ranking = MagicFormulaRunner.cachedRanking()
        }
    }

    func run() async {
        guard !isRunning else { return }
        isRunning = true
        progress = 0
        defer { isRunning = false }

        let result = await MagicFormulaRunner.run(progress: { [weak self] fraction in
            Task { @MainActor in
                self?.progress = fraction
            }
        })
        ranking = result
    }
}
