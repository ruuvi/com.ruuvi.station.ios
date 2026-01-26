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
        public let lastUpdated: Int?

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
            case lastUpdated
        }

        public var lastMeasurement: UserApiSensorRecord? {
            measurements?.first
        }

        public var lastUpdatedDate: Date? {
            guard let lastUpdated else { return nil }
            return Date(timeIntervalSince1970: TimeInterval(lastUpdated))
        }

        public var alerts: RuuviCloudSensorAlerts {
            RuuviCloudApiGetAlertSensor(
                sensor: sensor, apiAlerts: apiAlerts ?? []
            )
        }

        public struct CloudApiSensorSettings: Decodable {
            public let displayOrderCodes: [String]?
            public let defaultDisplayOrder: Bool?
            public let displayOrderLastUpdated: Int?
            public let defaultDisplayOrderLastUpdated: Int?

            enum CodingKeys: CodingKey {
                case displayOrder
                case defaultDisplayOrder
                case displayOrderLastUpdated
                case defaultDisplayOrderLastUpdated

                var stringValue: String {
                    switch self {
                    case .displayOrder:
                        return RuuviCloudApiSetting.sensorDisplayOrder.rawValue
                    case .defaultDisplayOrder:
                        return RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue
                    case .displayOrderLastUpdated:
                        return RuuviCloudApiSetting.sensorDisplayOrder.rawValue + "_lastUpdated"
                    case .defaultDisplayOrderLastUpdated:
                        return RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue + "_lastUpdated"
                    }
                }

                init?(stringValue: String) {
                    switch stringValue {
                    case RuuviCloudApiSetting.sensorDisplayOrder.rawValue:
                        self = .displayOrder
                    case RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue:
                        self = .defaultDisplayOrder
                    case RuuviCloudApiSetting.sensorDisplayOrder.rawValue + "_lastUpdated":
                        self = .displayOrderLastUpdated
                    case RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue + "_lastUpdated":
                        self = .defaultDisplayOrderLastUpdated
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

                displayOrderLastUpdated = try? container.decode(Int.self, forKey: .displayOrderLastUpdated)
                defaultDisplayOrderLastUpdated = try? container.decode(Int.self, forKey: .defaultDisplayOrderLastUpdated)
            }

            public var displayOrderLastUpdatedDate: Date? {
                guard let displayOrderLastUpdated else { return nil }
                return Date(timeIntervalSince1970: TimeInterval(displayOrderLastUpdated))
            }

            public var defaultDisplayOrderLastUpdatedDate: Date? {
                guard let defaultDisplayOrderLastUpdated else { return nil }
                return Date(timeIntervalSince1970: TimeInterval(defaultDisplayOrderLastUpdated))
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
