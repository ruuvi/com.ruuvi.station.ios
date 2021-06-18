import Foundation

public struct RuuviCloudApiGetSensorsRequest: Encodable {
    let sensor: String

    public init(sensor: String) {
        self.sensor = sensor
    }
}
