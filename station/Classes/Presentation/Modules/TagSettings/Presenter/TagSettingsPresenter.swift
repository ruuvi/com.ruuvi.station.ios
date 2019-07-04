import Foundation

class TagSettingsPresenter: TagSettingsModuleInput {
    weak var view: TagSettingsViewInput!
    var router: TagSettingsRouterInput!
    var backgroundPersistence: BackgroundPersistence!
    var ruuviTagService: RuuviTagService!
    var errorPresenter: ErrorPresenter!
    
    private var ruuviTag: RuuviTagRealm! { didSet { setupViewModel() } }
    private var humidity: Double? { didSet { viewModel.humidity.value = humidity } }
    private var viewModel: TagSettingsViewModel! { didSet { view.viewModel = viewModel } }
    
    func configure(ruuviTag: RuuviTagRealm, humidity: Double?) {
        self.viewModel = TagSettingsViewModel()
        self.ruuviTag = ruuviTag
        self.humidity = humidity
        viewModel.name.bind { [weak self] (observable, name) in
            if let name = name {
                self?.updateRuuviTag(name: name)
            }
        }
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
    
    func viewDidAskToCalibrateHumidity() {
        if let humidity = humidity {
            router.openHumidityCalibration(ruuviTag: ruuviTag, humidity: humidity)
        }
    }
}

// MARK: - Private
extension TagSettingsPresenter {
    private func setupViewModel() {
        viewModel.background.value = backgroundPersistence.background(for: ruuviTag.uuid)
        
        if ruuviTag.name == ruuviTag.uuid || ruuviTag.name == ruuviTag.mac {
            viewModel.name.value = nil
        } else {
            viewModel.name.value = ruuviTag.name
        }
        
        viewModel.humidity.value = humidity
        viewModel.humidityOffset.value = ruuviTag.humidityOffset
        viewModel.humidityOffsetDate.value = ruuviTag.humidityOffsetDate
    }
    
    private func updateRuuviTag(name: String) {
        let operation = ruuviTagService.update(name: name, of: ruuviTag)
        operation.on(failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }
}
