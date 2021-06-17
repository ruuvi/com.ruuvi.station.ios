import Foundation
import RuuviOntology

struct RuuviCloudApiPostAlertRequest: Encodable {
    let sensor: String
    let enabled: Bool
    let type: RuuviCloudAlertType
    let min: Double?
    let max: Double?
    let description: String?
    let counter: Int?
}
