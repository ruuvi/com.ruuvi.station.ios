import Foundation

class TagSettingsPresenter: TagSettingsModuleInput {
    weak var view: TagSettingsViewInput!
    var router: TagSettingsRouterInput!
    var backgroundPersistence: BackgroundPersistence!
    
    private var ruuviTag: RuuviTagRealm!
    
    func configure(ruuviTag: RuuviTagRealm) {
        self.ruuviTag = ruuviTag
        setupViewModel()
    }

}

// MARK: - TagSettingsViewOutput
extension TagSettingsPresenter: TagSettingsViewOutput {
    
}

// MARK: - Private
extension TagSettingsPresenter {
    private func setupViewModel() {
        let viewModel = TagSettingsViewModel()
        viewModel.background.value = backgroundPersistence.background(for: ruuviTag.uuid)
        viewModel.name.value = ruuviTag.name
        viewModel.humidityOffsetDate.value = ruuviTag.humidityOffsetDate
        view.viewModel = viewModel
    }
}
