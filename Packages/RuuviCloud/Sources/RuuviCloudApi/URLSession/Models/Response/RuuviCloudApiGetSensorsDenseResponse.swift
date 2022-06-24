import Foundation
import RuuviOntology

public struct RuuviCloudApiGetSensorsDenseResponse: Decodable {
    public let sensors: [CloudApiSensor]

    public struct CloudApiSensor: Decodable {
        public let sensor: String
        public let name: String
        public let picture: String
        public let isPublic: Bool
        public let canShare: Bool
        public let offsetTemperature: Double
        public let offsetHumidity: Double
        public let offsetPressure: Double
        public let sharedTo: [String]?
        public let measurements: [UserApiSensorRecord]?
        public let alerts: [RuuviCloudApiGetAlert]?

        enum CodingKeys: String, CodingKey {
            case sensor
            case name
            case picture
            case isPublic = "public"
            case canShare
            case offsetTemperature
            case offsetHumidity
            case offsetPressure
            case sharedTo
            case measurements
            case alerts
        }

        public var lastMeasurement: UserApiSensorRecord? {
            return measurements?.first
        }
    }
}
