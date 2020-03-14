import Foundation

protocol TagSettingsModuleInput: class {
    func configure(ruuviTag: RuuviTagRealmImpl, humidity: Double?)
}
