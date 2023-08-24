import Foundation

public struct RuuviCloudApiGetSensorResponse: Decodable {
    public let sensor: String?
    public let total: Int?
    public let name: String?
    public let measurements: [UserApiSensorRecord]?
}

public struct UserApiSensorRecord: Decodable {
    public let gwmac: String?
    public let coordinates: String?
    public let rssi: Int?
    public let timestamp: TimeInterval?
    public let data: String?
}

extension UserApiSensorRecord {
    public var date: Date {
        guard let timestamp = timestamp else {
            return Date()
        }
        return Date(timeIntervalSince1970: timestamp)
    }
}
