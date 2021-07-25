import Foundation

public struct RuuviCloudApiSensorUpdateRequest: Encodable {
    let sensor: String
    let name: String
    let offsetTemperature: Double?
    let offsetHumidity: Double?
    let offsetPressure: Double?

    public init(
        sensor: String,
        name: String,
        offsetTemperature: Double?,
        offsetHumidity: Double?,
        offsetPressure: Double?
    ) {
        self.sensor = sensor
        self.name = name
        self.offsetTemperature = offsetTemperature
        self.offsetHumidity = offsetHumidity
        self.offsetPressure = offsetPressure
    }
}
