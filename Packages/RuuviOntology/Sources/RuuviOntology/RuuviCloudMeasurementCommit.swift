import Foundation

/// A cloud measurement successfully committed to the latest-record table.
public struct RuuviCloudMeasurementCommit: Sendable {
    public let mac: String
    public let date: Date

    public static let notification = Notification.Name("RuuviCloudMeasurementCommit")
    public static let userInfoKey = "record"

    public init(mac: String, date: Date) {
        self.mac = mac
        self.date = date
    }

    /// Call from the database writer's commit hook to preserve persisted write order.
    public func publish() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.notification, object: nil, userInfo: [Self.userInfoKey: self])
        }
    }
}
