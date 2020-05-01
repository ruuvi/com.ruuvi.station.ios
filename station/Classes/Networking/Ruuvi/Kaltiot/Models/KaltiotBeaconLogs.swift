import Foundation

struct KaltiotBeaconLogs: Decodable {
    let id: String
    let history: [KaltiotBeaconLogItem]

    struct KaltiotBeaconLogItem: Decodable {
        let timestamp: Double
        let value: String
        var data: Data? {
            return value.hexDecimal
        }

        enum CodingKeys: String, CodingKey {
            case timestamp
            case value
        }
    }
    enum CodingKeys: String, CodingKey {
        case id
        case history
    }
}
