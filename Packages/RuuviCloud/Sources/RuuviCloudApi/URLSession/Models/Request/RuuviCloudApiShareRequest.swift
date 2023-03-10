import Foundation

public struct RuuviCloudApiShareRequest: Codable {
    let user: String?
    let sensor: String

    public init(user: String?, sensor: String) {
        self.user = user
        self.sensor = sensor
    }
}
