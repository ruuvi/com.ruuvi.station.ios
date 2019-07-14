import Foundation
import RealmSwift
import BTKit

class TagSettingsPresenter: TagSettingsModuleInput {
    weak var view: TagSettingsViewInput!
    var router: TagSettingsRouterInput!
    var backgroundPersistence: BackgroundPersistence!
    var ruuviTagService: RuuviTagService!
    var errorPresenter: ErrorPresenter!
    var photoPickerPresenter: PhotoPickerPresenter! { didSet { photoPickerPresenter.delegate = self  } }
    
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
        viewModel.background.value = backgroundPersistence.setNextDefaultBackground(for: ruuviTag.uuid)
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
        let finalName = name.isEmpty ? (ruuviTag.mac ?? ruuviTag.uuid) : name
        let operation = ruuviTagService.update(name: finalName, of: ruuviTag)
        operation.on(failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }
    
    func viewDidAskToCalibrateHumidity() {
        if let humidity = humidity {
            router.openHumidityCalibration(ruuviTag: ruuviTag, humidity: humidity)
        }
    }
    
    func viewDidAskToSelectBackground() {
        photoPickerPresenter.pick()
    }
    
    func viewDidTapOnMacAddress() {
        view.showMacAddressDetail()
    }
}

// MARK: - PhotoPickerPresenterDelegate
extension TagSettingsPresenter: PhotoPickerPresenterDelegate {
    func photoPicker(presenter: PhotoPickerPresenter, didPick photo: UIImage) {
        let set = backgroundPersistence.setCustomBackground(image: photo, for: ruuviTag.uuid)
        set.on(success: { [weak self] _ in
            self?.viewModel.background.value = photo
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
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
        
        viewModel.mac.value = ruuviTag.mac
        viewModel.uuid.value = ruuviTag.uuid
        viewModel.version.value = ruuviTag.version
        
        viewModel.humidity.value = humidity
        viewModel.humidityOffset.value = ruuviTag.humidityOffset
        viewModel.humidityOffsetDate.value = ruuviTag.humidityOffsetDate
        
        viewModel.humidity.value = ruuviTag.data.last?.humidity.value
        
        viewModel.voltage.value = ruuviTag.data.last?.voltage.value
        viewModel.accelerationX.value = ruuviTag.data.last?.accelerationX.value
        viewModel.accelerationY.value = ruuviTag.data.last?.accelerationY.value
        viewModel.accelerationZ.value = ruuviTag.data.last?.accelerationZ.value
        viewModel.movementCounter.value = ruuviTag.data.last?.movementCounter.value
        viewModel.measurementSequenceNumber.value = ruuviTag.data.last?.measurementSequenceNumber.value
        viewModel.txPower.value = ruuviTag.data.last?.txPower.value
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
        viewModel.voltage.value = device.voltage
        viewModel.accelerationX.value = device.accelerationX
        viewModel.accelerationY.value = device.accelerationY
        viewModel.accelerationZ.value = device.accelerationZ
        viewModel.version.value = device.version
        viewModel.mac.value = device.mac
        viewModel.movementCounter.value = device.movementCounter
        viewModel.measurementSequenceNumber.value = device.measurementSequenceNumber
        viewModel.txPower.value = device.txPower
    }
}
