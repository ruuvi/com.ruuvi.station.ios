import Foundation

struct UserApiGetSensorResponse: Decodable {
    let sensor: String
    let total: Int
    let measurements: [UserApiSensorRecord]
}

struct UserApiSensorRecord: Decodable {
    let sensor: String
    let gwmac: String
    let coordinates: String
    let rssi: Int
    let timestamp: TimeInterval
    let data: String
}
