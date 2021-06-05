import Foundation

enum RuuviCloudApiAlertType: String, Encodable {
    case temperature
    case humidity
    case pressure
}

struct RuuviCloudApiPostAlertRequest: Encodable {
    let sensor: String
    let enabled: Bool
    let type: RuuviCloudApiAlertType
    let min: Double
    let max: Double
}
