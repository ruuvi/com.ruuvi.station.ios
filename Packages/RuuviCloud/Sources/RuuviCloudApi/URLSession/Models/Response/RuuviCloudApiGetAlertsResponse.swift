import Foundation
import RuuviOntology

struct RuuviCloudApiGetAlertsResponse: Decodable {
    var sensors: [RuuviCloudApiGetAlertSensor]
}

struct RuuviCloudApiGetAlertSensor: Decodable, RuuviCloudSensorAlerts {
    let sensor: String
    let apiAlerts: [RuuviCloudApiGetAlert]
    var alerts: [RuuviCloudAlert] {
        return apiAlerts
    }

    enum CodingKeys: String, CodingKey {
        case sensor
        case apiAlerts = "alerts"
    }
}

struct RuuviCloudApiGetAlert: Decodable, RuuviCloudAlert {
    let type: RuuviCloudAlertType
    let enabled: Bool
    let min: Double
    let max: Double
    let counter: Int
    let description: String
}
