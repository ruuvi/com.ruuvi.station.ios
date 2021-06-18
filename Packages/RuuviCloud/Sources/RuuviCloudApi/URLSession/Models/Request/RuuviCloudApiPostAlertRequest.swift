import Foundation
import RuuviOntology

public struct RuuviCloudApiPostAlertRequest: Encodable {
    let sensor: String
    let enabled: Bool
    let type: RuuviCloudAlertType
    let min: Double?
    let max: Double?
    let description: String?
    let counter: Int?

    public init(
        sensor: String,
        enabled: Bool,
        type: RuuviCloudAlertType,
        min: Double?,
        max: Double?,
        description: String?,
        counter: Int?
    ) {
        self.sensor = sensor
        self.enabled = enabled
        self.type = type
        self.min = min
        self.max = max
        self.description = description
        self.counter = counter
    }
}
