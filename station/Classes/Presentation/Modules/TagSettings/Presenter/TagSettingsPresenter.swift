import Foundation
import RealmSwift
import BTKit

class TagSettingsPresenter: TagSettingsModuleInput {
    weak var view: TagSettingsViewInput!
    var router: TagSettingsRouterInput!
    var backgroundPersistence: BackgroundPersistence!
    var ruuviTagService: RuuviTagService!
    var errorPresenter: ErrorPresenter!

    private let scanner = Ruuvi.scanner
    private var ruuviTag: RuuviTagRealm! { didSet { syncViewModel() } }
    private var humidity: Double? { didSet { viewModel.humidity.value = humidity } }
    private var viewModel: TagSettingsViewModel! { didSet { view.viewModel = viewModel } }
    private var ruuviTagToken: NotificationToken?
    private var observeToken: ObservationToken?
    
    deinit {
        ruuviTagToken?.invalidate()
        observeToken?.invalidate()
    }
    
    func configure(ruuviTag: RuuviTagRealm, humidity: Double?) {
        self.viewModel = TagSettingsViewModel()
        self.ruuviTag = ruuviTag
        self.humidity = humidity
        startObservingRuuviTag()
        startScanningRuuviTag()
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
    
    func viewDidChangeTag(name: String) {
        let operation = ruuviTagService.update(name: name, of: ruuviTag)
        operation.on(failure: { [weak self] (error) in
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
    private func syncViewModel() {
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
    
    private func startObservingRuuviTag() {
        ruuviTagToken = ruuviTag.observe { [weak self] (change) in
            switch change {
            case .change:
                self?.syncViewModel()
            case .deleted:
                self?.router.dismiss()
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        }
    }
    
    private func startScanningRuuviTag() {
        observeToken = scanner.observe(self, uuid: ruuviTag.uuid, closure: { [weak self] (observer, device) in
            if let tag = device.ruuvi?.tag {
                self?.sync(device: tag)
            }
        })
    }
    
    private func sync(device: RuuviTag) {
        viewModel.humidity.value = device.humidity
    }
}
