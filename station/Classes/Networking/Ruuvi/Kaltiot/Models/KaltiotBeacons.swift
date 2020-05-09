import Foundation

// MARK: - KaltiotBeacons
struct KaltiotBeacons: Decodable {
    let beacons: [KaltiotBeacon]
    let pages: Int
}

// MARK: - Beacon
struct KaltiotBeacon: Decodable {
    // MARK: - Propeties
    let id: String
    let timestamp: TimeInterval?
    let movable: Bool
    let meta: Meta?
    let trackableID: String?
    let latitude, longitude: Int?
    let accuracy: Double?
    let customerID: String?
    let isPhone: Bool?

    enum CodingKeys: String, CodingKey {
        case id, movable, meta
        case trackableID = "trackable_id"
        case latitude, longitude, accuracy, timestamp
        case customerID = "customer_id"
        case isPhone = "is_phone"
    }
    // MARK: - Meta
    struct Meta: Decodable {
        let capabilities: Capabilities
    }

    struct Capabilities: Decodable {
        let sensors: [Sensor]
    }

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
}
