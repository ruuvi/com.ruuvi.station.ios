import Foundation
import RuuviOntology

public struct RuuviCloudApiGetAlertsResponse: Decodable {
    public var sensors: [RuuviCloudApiGetAlertSensor]?
}

public struct RuuviCloudApiGetAlertSensor: Decodable, RuuviCloudSensorAlerts {
    public let sensor: String?
    public let apiAlerts: [RuuviCloudApiGetAlert]?

    public var alerts: [RuuviCloudAlert]? {
        return apiAlerts
    }

    enum CodingKeys: String, CodingKey {
        case sensor
        case apiAlerts = "alerts"
    }
}

public struct RuuviCloudApiGetAlert: Decodable, RuuviCloudAlert {
    public let type: RuuviCloudAlertType?
    public let enabled: Bool?
    public let min: Double?
    public let max: Double?
    public let counter: Int?
    public let delay: Int?
    public let description: String?

    enum CodingKeys: String, CodingKey {
        case type, enabled, min, max, counter, delay, description
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let typeString = try? container.decode(String.self, forKey: .type),
           let type = RuuviCloudAlertType(rawValue: typeString) {
            self.type = type
        } else {
            self.type = nil
        }

        enabled = try container.decode(Bool.self, forKey: .enabled)
        min = try container.decode(Double.self, forKey: .min)
        max = try container.decode(Double.self, forKey: .max)
        counter = try container.decode(Int.self, forKey: .counter)
        description = try container.decode(String.self, forKey: .description)

        if let delay = try? container.decode(Int.self, forKey: .delay) {
            self.delay = delay
        } else {
            self.delay = nil
        }
    }
}
