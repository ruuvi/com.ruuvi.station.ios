import Foundation

class TagSettingsPresenter: TagSettingsModuleInput {
    weak var view: TagSettingsViewInput!
    var router: TagSettingsRouterInput!
    var backgroundPersistence: BackgroundPersistence!
    
    private var ruuviTag: RuuviTagRealm! { didSet { setupViewModel() } }
    private var viewModel: TagSettingsViewModel! { didSet { view.viewModel = viewModel } }
    
    func configure(ruuviTag: RuuviTagRealm) {
        self.viewModel = TagSettingsViewModel()
        self.ruuviTag = ruuviTag
    }

}

// MARK: - TagSettingsViewOutput
extension TagSettingsPresenter: TagSettingsViewOutput {
    func viewDidAskToDismiss() {
        router.dismiss()
    }
    
    func viewDidAskToRandomizeBackground() {
        viewModel.background.value = backgroundPersistence.setNextBackground(for: ruuviTag.uuid)
    }
}

// MARK: - Private
extension TagSettingsPresenter {
    private func setupViewModel() {
        viewModel.background.value = backgroundPersistence.background(for: ruuviTag.uuid)
        viewModel.name.value = ruuviTag.name
        viewModel.humidityOffsetDate.value = ruuviTag.humidityOffsetDate
    }
}
