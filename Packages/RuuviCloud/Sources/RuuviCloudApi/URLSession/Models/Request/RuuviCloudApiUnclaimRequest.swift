import Foundation

public struct RuuviCloudApiUnclaimRequest: Codable {
    let sensor: String
    let deleteData: Bool

    public init(sensor: String, deleteData: Bool) {
        self.sensor = sensor
        self.deleteData = deleteData
    }
}
