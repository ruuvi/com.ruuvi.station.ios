import Foundation
import RuuviOntology

public struct RuuviCloudApiGetSensorsDenseResponse: Decodable {
    public let sensors: [CloudApiSensor]?

    public struct CloudApiSensor: Decodable {
        public let sensor: String
        public let owner: String
        public let name: String
        public let picture: String
        public let isPublic: Bool
        public let canShare: Bool
        public let offsetTemperature: Double?
        public let offsetHumidity: Double?
        public let offsetPressure: Double?
        public let sharedTo: [String]?
        public let measurements: [UserApiSensorRecord]?
        public let apiAlerts: [RuuviCloudApiGetAlert]?
        public let subscription: RuuviCloudApiGetSensorSubsription?

        enum CodingKeys: String, CodingKey {
            case sensor
            case owner
            case name
            case picture
            case isPublic = "public"
            case canShare
            case offsetTemperature
            case offsetHumidity
            case offsetPressure
            case sharedTo
            case measurements
            case apiAlerts = "alerts"
            case subscription
        }

        public var lastMeasurement: UserApiSensorRecord? {
            measurements?.first
        }

        public var alerts: RuuviCloudSensorAlerts {
            RuuviCloudApiGetAlertSensor(
                sensor: sensor, apiAlerts: apiAlerts ?? []
            )
        }
    }

    public struct RuuviCloudApiGetSensorSubsription: Codable, CloudSensorSubscription {
        public let maxHistoryDays: Int?
        public let pushAlertAllowed: Bool?
        public let subscriptionName: String?
        public let maxResolutionMinutes: Int?
        public let emailAlertAllowed: Bool?
    }
}
