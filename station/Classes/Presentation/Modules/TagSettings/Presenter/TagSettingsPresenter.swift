import Foundation

class TagSettingsPresenter: TagSettingsModuleInput {
    weak var view: TagSettingsViewInput!
    var router: TagSettingsRouterInput!
    var backgroundPersistence: BackgroundPersistence!
    
    private var ruuviTag: RuuviTagRealm! { didSet { setupViewModel() } }
    private var viewModel: TagSettingsViewModel!
    
    func configure(ruuviTag: RuuviTagRealm) {
        self.viewModel = TagSettingsViewModel()
        self.ruuviTag = ruuviTag
        view.viewModel = viewModel
    }

}

// MARK: - TagSettingsViewOutput
extension TagSettingsPresenter: TagSettingsViewOutput {
    func viewDidAskToDismiss() {
        router.dismiss()
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
