import Foundation

protocol TagSettingsModuleOutput: class {
    func tagSettingsDidDeleteTag(module: TagSettingsModuleInput,
                                 ruuviTag: RuuviTagSensor)
}
