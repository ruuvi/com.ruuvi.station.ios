import Foundation

enum QueuedOffsetType: Hashable {
    case temperature
    case humidity
    case pressure
}

struct QueuedOffsetUpdate: Hashable {
    let sensorID: String
    let type: QueuedOffsetType
}

struct QueuedSensorUpdateRequest: Decodable {
    let sensor: String
    let offsetTemperature: Double?
    let offsetHumidity: Double?
    let offsetPressure: Double?
}
