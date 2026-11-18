import Foundation
import BackgroundTasks

/// Schedules periodic background refresh used to check price/rating alerts.
enum AppBackground {
    static let refreshID = "com.stockwatcher.refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: refreshID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Double(SettingsStore.shared.refreshMinutes * 60))
        try? BGTaskScheduler.shared.submit(request)
    }
}
