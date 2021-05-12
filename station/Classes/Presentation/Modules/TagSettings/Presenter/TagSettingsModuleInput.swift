import Foundation

protocol TagSettingsModuleInput: AnyObject {
    func configure(
        ruuviTag: RuuviTagSensor,
        temperature: Temperature?,
        humidity: Humidity?,
        output: TagSettingsModuleOutput
    )
    func dismiss(completion: (() -> Void)?)
}
