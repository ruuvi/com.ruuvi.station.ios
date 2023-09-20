import Foundation

public enum RuuviCloudAlertType: String, Codable {
    case temperature
    case humidity
    case pressure
    case signal
    case movement
    case offline
}

public enum RuuviCloudAlertSettingType: String {
    case state
    case lowerBound
    case upperBound
    case description
    case delay
}

public protocol RuuviCloudSensorAlerts {
    var sensor: String? { get }
    var alerts: [RuuviCloudAlert]? { get }
}

public protocol RuuviCloudAlert {
    var type: RuuviCloudAlertType? { get }
    var enabled: Bool? { get }
    var min: Double? { get }
    var max: Double? { get }
    var counter: Int? { get }
    var delay: Int? { get }
    var description: String? { get }
    var triggered: Bool? { get }
    var triggeredAt: String? { get }
}
