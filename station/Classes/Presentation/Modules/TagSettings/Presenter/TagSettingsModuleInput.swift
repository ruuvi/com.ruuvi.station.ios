import Foundation

protocol TagSettingsModuleInput: class {
    func configure(ruuviTag: RuuviTagSensor, humidity: Double?, output: TagSettingsModuleOutput)
    func dismiss(completion: (() -> Void)?)
}
