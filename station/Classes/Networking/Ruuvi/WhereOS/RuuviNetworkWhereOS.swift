import Foundation
import Future

protocol RuuviNetworkWhereOS: RuuviNetwork {

    func load(mac: String) -> Future<[WhereOSData],RUError>
}

/**
 {
     "rssi": -65,
     "data": "0201041bff99040511203205c919ffb800340408a2f6a1b372c04db14ab635",
     "coordinates": "Saase",
     "rssi_max": -63,
     "time": "2020-04-10T07:00:00.000Z",
     "id": "c04db14ab635",
     "gwmac": "30aea4cc1e2f",
     "rssi_min": -72
 }
 */
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
