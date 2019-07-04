import Foundation

class TagSettingsPresenter: TagSettingsModuleInput {
    weak var view: TagSettingsViewInput!
    var router: TagSettingsRouterInput!
    var backgroundPersistence: BackgroundPersistence!
    var ruuviTagService: RuuviTagService!
    var errorPresenter: ErrorPresenter!
    
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
    
    func viewDidAskToRemoveRuuviTag() {
        view.showTagRemovalConfirmationDialog()
    }
    
    func viewDidConfirmTagRemoval() {
        let operation = ruuviTagService.delete(ruuviTag: ruuviTag)
        operation.on(success: { [weak self] _ in
            self?.router.dismiss()
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
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
