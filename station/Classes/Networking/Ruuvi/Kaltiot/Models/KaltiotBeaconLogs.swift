import Foundation

struct KaltiotBeaconLogs: Decodable {
    let id: String
    let history: [KaltiotBeaconLogItem]

    struct KaltiotBeaconLogItem: Decodable {
        let timestamp: Double
        let value: String
        var date: Date {
            return Date(timeIntervalSince1970: timestamp / 1000)
        }
    }
    enum CodingKeys: String, CodingKey {
        case id
        case history
    }
}
