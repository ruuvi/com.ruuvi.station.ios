import Foundation

struct RuuviCloudApiSensorUpdateRequest: Encodable {
    let sensor: String
    let name: String
}
