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
        public let settings: CloudApiSensorSettings?

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
            case settings
        }

        public var lastMeasurement: UserApiSensorRecord? {
            measurements?.first
        }

        public var alerts: RuuviCloudSensorAlerts {
            RuuviCloudApiGetAlertSensor(
                sensor: sensor, apiAlerts: apiAlerts ?? []
            )
        }

        public struct CloudApiSensorSettings: Decodable {
            public let displayOrderCodes: [String]?
            public let defaultDisplayOrder: Bool?

            enum CodingKeys: CodingKey {
                case displayOrder
                case defaultDisplayOrder

                var stringValue: String {
                    switch self {
                    case .displayOrder:
                        return RuuviCloudApiSetting.sensorDisplayOrder.rawValue
                    case .defaultDisplayOrder:
                        return RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue
                    }
                }

                init?(stringValue: String) {
                    switch stringValue {
                    case RuuviCloudApiSetting.sensorDisplayOrder.rawValue:
                        self = .displayOrder
                    case RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue:
                        self = .defaultDisplayOrder
                    default:
                        return nil
                    }
                }

                var intValue: Int? { nil }

                init?(intValue: Int) {
                    return nil
                }
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)

                if let codes = try? container.decode([String].self, forKey: .displayOrder) {
                    displayOrderCodes = codes
                } else if let raw = try? container.decode(String.self, forKey: .displayOrder) {
                    displayOrderCodes = CloudApiSensorSettings.parseDisplayOrder(raw)
                } else {
                    displayOrderCodes = nil
                }

                if let flag = try? container.decode(Bool.self, forKey: .defaultDisplayOrder) {
                    defaultDisplayOrder = flag
                } else if let rawFlag = try? container.decode(String.self, forKey: .defaultDisplayOrder) {
                    defaultDisplayOrder = CloudApiSensorSettings.parseBoolean(rawFlag)
                } else {
                    defaultDisplayOrder = nil
                }
            }

            private static func parseDisplayOrder(_ raw: String) -> [String]? {
                guard let data = raw.data(using: .utf8) else {
                    return nil
                }
                if let decoded = try? JSONDecoder().decode([String].self, from: data) {
                    return decoded
                }
                if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                   let decoded = jsonObject as? [String] {
                    return decoded
                }
                return nil
            }

            private static func parseBoolean(_ raw: String) -> Bool? {
                switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true":
                    return true
                case "false":
                    return false
                default:
                    return nil
                }
            }
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
