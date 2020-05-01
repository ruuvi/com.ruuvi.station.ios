import Foundation

struct KaltiotBeaconLogs: Decodable {
    let id: String
    let history: [KaltiotBeaconLogItem]

    struct KaltiotBeaconLogItem: Decodable {
        let timestamp: Double
        let value: String
    }
    enum CodingKeys: String, CodingKey {
        case id
        case history
    }
}
