import Foundation
import RuuviOntology

public struct RuuviCloudApiGetAlertsResponse: Decodable {
    public var sensors: [RuuviCloudApiGetAlertSensor]
}

public struct RuuviCloudApiGetAlertSensor: Decodable, RuuviCloudSensorAlerts {
    public let sensor: String
    let apiAlerts: [RuuviCloudApiGetAlert]
    public var alerts: [RuuviCloudAlert] {
        return apiAlerts
    }

    enum CodingKeys: String, CodingKey {
        case sensor
        case apiAlerts = "alerts"
    }
}

public struct RuuviCloudApiGetAlert: Decodable, RuuviCloudAlert {
    public let type: RuuviCloudAlertType
    public let enabled: Bool
    public let min: Double
    public let max: Double
    public let counter: Int
    public let description: String
}
