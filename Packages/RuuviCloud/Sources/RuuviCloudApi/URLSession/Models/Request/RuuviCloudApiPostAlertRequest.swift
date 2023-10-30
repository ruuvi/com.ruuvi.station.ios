import Foundation
import RuuviOntology

public struct RuuviCloudApiPostAlertRequest: Codable {
    let sensor: String
    let enabled: Bool
    let type: RuuviCloudAlertType
    let min: Double?
    let max: Double?
    let description: String?
    let counter: Int?
    let delay: Int?
    let timestamp: Int?

    public init(
        sensor: String,
        enabled: Bool,
        type: RuuviCloudAlertType,
        min: Double?,
        max: Double?,
        description: String?,
        counter: Int?,
        delay: Int?,
        timestamp: Int?
    ) {
        self.sensor = sensor
        self.enabled = enabled
        self.type = type
        self.min = min
        self.max = max
        self.description = description
        self.counter = counter
        self.delay = delay
        self.timestamp = timestamp
    }
}
