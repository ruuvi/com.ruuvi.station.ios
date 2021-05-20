import Foundation

protocol TagSettingsModuleInput: class {
    func configure(
        ruuviTag: RuuviTagSensor,
        temperature: Temperature?,
        humidity: Humidity?,
        sensor: SensorSettings?,
        output: TagSettingsModuleOutput
    )
    func dismiss(completion: (() -> Void)?)
}
