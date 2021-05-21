import Foundation

protocol TagSettingsModuleOutput: AnyObject {
    func tagSettingsDidDeleteTag(module: TagSettingsModuleInput,
                                 ruuviTag: RuuviTagSensor)
}
