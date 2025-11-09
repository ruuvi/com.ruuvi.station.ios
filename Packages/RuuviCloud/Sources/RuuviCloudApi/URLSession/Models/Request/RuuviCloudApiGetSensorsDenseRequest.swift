import Foundation

public struct RuuviCloudApiGetSensorsDenseRequest: Encodable {
    let sensor: String?
    let measurements: Bool?
    let sharedToMe: Bool?
    let sharedToOthers: Bool?
    let alerts: Bool?
    let settings: Bool?

    public init(
        sensor: String?,
        measurements: Bool?,
        sharedToMe: Bool?,
        sharedToOthers: Bool?,
        alerts: Bool?,
        settings: Bool?
    ) {
        self.sensor = sensor
        self.measurements = measurements
        self.sharedToMe = sharedToMe
        self.sharedToOthers = sharedToOthers
        self.alerts = alerts
        self.settings = settings
    }
}
