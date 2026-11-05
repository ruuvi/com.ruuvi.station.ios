import Foundation
import Intents

public struct SingleSensorWidgetConfiguration: Equatable {
    let sensorId: String?
    let deviceType: RuuviDeviceType
    let sensorSelectionIdentifier: String?
    let sensor: WidgetSensorEnum?
}

extension SingleSensorWidgetConfiguration {
    static let preview = SingleSensorWidgetConfiguration(
        sensorId: nil,
        deviceType: .unknown,
        sensorSelectionIdentifier: nil,
        sensor: .temperature
    )
}

extension SingleSensorWidgetConfiguration {
    init(intent: RuuviTagSelectionIntent) {
        self.init(
            sensorId: WidgetConfigurationSelection.normalizedSensorIdentifier(
                from: intent.ruuviWidgetTag
            ),
            deviceType: intent.ruuviWidgetTag?.deviceType ?? .unknown,
            sensorSelectionIdentifier: intent.sensorSelection?.identifier,
            sensor: WidgetSensorEnum(rawValue: intent.sensor.rawValue)
        )
    }
}
