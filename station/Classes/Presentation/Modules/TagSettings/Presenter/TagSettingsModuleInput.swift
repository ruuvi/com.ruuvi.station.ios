import Foundation

protocol TagSettingsModuleInput: class {
    func configure(ruuviTag: RuuviTagSensor, humidity: Humidity?, output: TagSettingsModuleOutput)
    func dismiss(completion: (() -> Void)?)
}
