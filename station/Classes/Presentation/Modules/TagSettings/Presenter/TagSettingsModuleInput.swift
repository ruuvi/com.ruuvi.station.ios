import Foundation

protocol TagSettingsModuleInput: class {
    func configure(ruuviTag: RuuviTagSensor, temperature: Temperature?, humidity: Humidity?, output: TagSettingsModuleOutput)
    func dismiss(completion: (() -> Void)?)
}
