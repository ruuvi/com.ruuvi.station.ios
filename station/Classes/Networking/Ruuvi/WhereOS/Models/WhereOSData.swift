import Foundation

struct WhereOSData: Codable {
    var rssi: Int
    var rssiMax: Int
    var rssiMin: Int
    var data: String
    var coordinates: String
    var time: Date
    var id: String
    var gwmac: String
}
