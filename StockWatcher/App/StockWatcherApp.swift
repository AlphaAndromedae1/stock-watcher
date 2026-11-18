import SwiftUI

@main
struct StockWatcherApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.accentColor)
        }
        .backgroundTask(.appRefresh(AppBackground.refreshID)) {
            await NotificationManager.shared.checkAndNotify()
            AppBackground.schedule()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { AppBackground.schedule() }
        }
    }
}
