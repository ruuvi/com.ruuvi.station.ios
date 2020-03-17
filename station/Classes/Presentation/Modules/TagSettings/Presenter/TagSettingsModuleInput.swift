import Foundation

protocol TagSettingsModuleInput: class {
    func configure(ruuviTag: RuuviTagRealm, humidity: Double?)
}
