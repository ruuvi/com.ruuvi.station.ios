import Foundation

class TagSettingsPresenter: TagSettingsModuleInput {
    weak var view: TagSettingsViewInput!
    var router: TagSettingsRouterInput!
    
    private var ruuviTag: RuuviTagRealm!
    
    func configure(ruuviTag: RuuviTagRealm) {
        self.ruuviTag = ruuviTag
    }

}

extension TagSettingsPresenter: TagSettingsViewOutput {
    
}
