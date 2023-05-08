import Foundation

public protocol CloudSensorSubscription {
    var maxHistoryDays: Int? { get }
    var pushAlertAllowed: Bool? { get }
    var subscriptionName: String? { get }
    var maxResolutionMinutes: Int? { get }
    var emailAlertAllowed: Bool? { get }
}
