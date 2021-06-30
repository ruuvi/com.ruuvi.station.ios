import Foundation

public struct RuuviCloudApiShareRequest: Encodable {
    let user: String?
    let sensor: String

    public init(user: String?, sensor: String) {
        self.user = user
        self.sensor = sensor
    }
}
