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
        }
        .backgroundTask(.appRefresh(AppBackground.refreshID)) {
            await NotificationManager.shared.checkAndNotify()
            AppBackground.schedule()
        }
    }
}
