import Foundation

struct RuuviCloudApiSensorUpdateRequest: Encodable {
    let sensor: String
    let name: String
    let offsetTemperature: Double?
    let offsetHumidity: Double?
    let offsetPressure: Double?
}
