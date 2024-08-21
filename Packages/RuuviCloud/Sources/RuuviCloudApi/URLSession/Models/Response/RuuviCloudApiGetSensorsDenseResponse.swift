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
        public var macId: String?
        public var subscriptionName: String?
        public var isActive: Bool?
        public var maxClaims: Int?
        public var maxHistoryDays: Int?
        public var maxResolutionMinutes: Int?
        public var maxShares: Int?
        public var maxSharesPerSensor: Int?
        public var delayedAlertAllowed: Bool?
        public var emailAlertAllowed: Bool?
        public var offlineAlertAllowed: Bool?
        public var pdfExportAllowed: Bool?
        public var pushAlertAllowed: Bool?
        public var telegramAlertAllowed: Bool?
        public var endAt: String?
    }
}
