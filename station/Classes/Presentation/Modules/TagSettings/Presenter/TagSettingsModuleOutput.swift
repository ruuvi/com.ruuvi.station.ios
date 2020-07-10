import Foundation

protocol TagSettingsModuleOutput: class {
    func tagSettingsDidDeleteTag(ruuviTag: RuuviTagSensor)
}
