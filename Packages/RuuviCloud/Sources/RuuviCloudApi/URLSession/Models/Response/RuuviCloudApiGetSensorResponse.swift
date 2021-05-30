import Foundation

struct RuuviCloudApiGetSensorResponse: Decodable {
    let sensor: String
    let total: Int
    let name: String
    let measurements: [UserApiSensorRecord]
}

struct UserApiSensorRecord: Decodable {
    let gwmac: String
    let coordinates: String
    let rssi: Int
    let timestamp: TimeInterval
    let data: String
}

extension UserApiSensorRecord {
    var date: Date {
        return Date(timeIntervalSince1970: timestamp)
    }
}
