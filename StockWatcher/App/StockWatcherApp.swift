import SwiftUI

@main
struct StockWatcherApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.accentColor)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { AppBackground.schedule() }
                }
                .task {
                    // Keep the on-device cache from growing: drop anything untouched for a week.
                    await Task.detached(priority: .utility) {
                        _ = DataCache.shared.purge(olderThan: 7 * 24 * 60 * 60)
                    }.value
                }
        }
        .backgroundTask(.appRefresh(AppBackground.refreshID)) {
            await NotificationManager.shared.checkAndNotify()
            AppBackground.schedule()
        }
    }
}
