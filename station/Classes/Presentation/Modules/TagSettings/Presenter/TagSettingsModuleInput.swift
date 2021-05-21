import Foundation

protocol TagSettingsModuleInput: AnyObject {
    func configure(
        ruuviTag: RuuviTagSensor,
        temperature: Temperature?,
        humidity: Humidity?,
        sensor: SensorSettings?,
        output: TagSettingsModuleOutput
    )
    func dismiss(completion: (() -> Void)?)
}
