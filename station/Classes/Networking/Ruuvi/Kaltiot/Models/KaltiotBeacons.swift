import Foundation

// MARK: - KaltiotBeacons
struct KaltiotBeacons: Decodable {
    let beacons: [KaltiotBeacon]
    let pages: Int
}

// MARK: - Beacon
struct KaltiotBeacon: Decodable {
    // MARK: - Meta
    struct Meta: Decodable {
        struct Capabilities: Decodable {
            enum Sensor: String, Decodable {
                case batterylevel = "batterylevel"
                case collisionX = "collision_x"
                case collisionY = "collision_y"
                case collisionZ = "collision_z"
                case hexdump = "hexdump"
                case humidity = "humidity"
                case pressure = "pressure"
                case temperature = "temperature"
                case txpower = "txpower"
            }
            let sensors: [Sensor]
        }
        let capabilities: Capabilities
    }
    // MARK: - UpdatedBy
    struct UpdatedBy: Decodable {
        let trackableID: String?
        let id: String?

        enum CodingKeys: String, CodingKey {
            case trackableID = "trackableId"
            case id
        }
    }
    // MARK: - Propeties
    let id: String
    let timestamp: TimeInterval?
    let movable: Bool
    let meta: Meta?
    let trackableID: String?
    let latitude, longitude: Int?
    let accuracy: Double?
    let customerID: String?
    let updatedBy: UpdatedBy?
    let isPhone: Bool?

    enum CodingKeys: String, CodingKey {
        case id, movable, meta
        case trackableID = "trackable_id"
        case latitude, longitude, accuracy, timestamp
        case customerID = "customer_id"
        case updatedBy = "updated_by"
        case isPhone = "is_phone"
    }
}
