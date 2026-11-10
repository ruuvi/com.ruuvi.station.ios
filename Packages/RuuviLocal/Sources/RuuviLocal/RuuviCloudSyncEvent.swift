import Foundation

/// Correlates concurrent refreshes and the measurement dates committed before their completion.
public enum RuuviCloudSyncEvent: Sendable {
    case started(UUID)
    case recordsSaved([String: Date])
    case finished(UUID)

    public static let notification = Notification.Name("RuuviCloudSync.MeasurementProgress")
    public static let userInfoKey = "event"

    public func publish() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.notification, object: nil, userInfo: [Self.userInfoKey: self])
        }
    }
}
