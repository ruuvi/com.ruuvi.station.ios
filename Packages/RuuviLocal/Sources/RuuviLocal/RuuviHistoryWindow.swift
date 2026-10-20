import Foundation

/// Presentation limit only: older database records remain available internally.
public enum RuuviHistoryWindow {
    public static func start(now: Date = Date(), limitHours: Int, requestedHours: Int? = nil) -> Date {
        let limit = max(0, limitHours)
        let hours = min(limit, max(0, requestedHours ?? limit))
        return now.addingTimeInterval(-TimeInterval(hours) * 60 * 60)
    }
}
