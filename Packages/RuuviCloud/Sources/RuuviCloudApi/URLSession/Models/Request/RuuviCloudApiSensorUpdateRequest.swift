import Foundation

public struct RuuviCloudApiSensorUpdateRequest: Encodable, Decodable {
    let sensor: String
    let name: String
    let offsetTemperature: Double?
    let offsetHumidity: Double?
    let offsetPressure: Double?
    let timestamp: Int?

    public init(
        sensor: String,
        name: String,
        offsetTemperature: Double?,
        offsetHumidity: Double?,
        offsetPressure: Double?,
        timestamp: Int?
    ) {
        self.sensor = sensor
        self.name = name
        self.offsetTemperature = offsetTemperature
        self.offsetHumidity = offsetHumidity
        self.offsetPressure = offsetPressure
        self.timestamp = timestamp
    }
}
