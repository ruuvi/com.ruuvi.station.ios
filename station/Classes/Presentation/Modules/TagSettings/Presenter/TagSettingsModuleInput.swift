import Foundation
import RuuviOntology

protocol TagSettingsModuleInput: AnyObject {
    // swiftlint:disable:next function_parameter_count
    func configure(
        ruuviTag: RuuviTagSensor,
        temperature: Temperature?,
        humidity: Humidity?,
        rssi: Int?,
        sensor: SensorSettings?,
        output: TagSettingsModuleOutput,
        scrollToAlert: Bool
    )
    func dismiss(completion: (() -> Void)?)
}
