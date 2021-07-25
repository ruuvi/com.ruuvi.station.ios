import Foundation

public struct RuuviCloudApiClaimRequest: Encodable {
    let name: String?
    let sensor: String

    public init(name: String?, sensor: String) {
        self.name = name
        self.sensor = sensor
    }
}
