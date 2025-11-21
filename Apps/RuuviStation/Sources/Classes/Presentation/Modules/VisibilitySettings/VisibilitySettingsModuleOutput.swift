protocol VisibilitySettingsModuleOutput: AnyObject {
    func visibilitySettingsModuleDidFinish(_ module: VisibilitySettingsModuleInput)
}

extension VisibilitySettingsModuleOutput {
    func visibilitySettingsModuleDidFinish(_ module: VisibilitySettingsModuleInput) {}
}
