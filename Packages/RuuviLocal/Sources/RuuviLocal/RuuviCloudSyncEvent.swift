import Foundation

/// Correlates the lifetime of concurrent sensor/measurement sync operations.
public enum RuuviCloudSyncEvent: Sendable {
    case started(UUID)
    case finished(UUID)

    public static let notification = Notification.Name("RuuviCloudSync.MeasurementProgress")
    public static let userInfoKey = "event"

    public func publish() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.notification, object: nil, userInfo: [Self.userInfoKey: self])
        }
    }
}
