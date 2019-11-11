import Foundation
import RealmSwift
import BTKit

class TagSettingsPresenter: NSObject, TagSettingsModuleInput {
    weak var view: TagSettingsViewInput!
    var router: TagSettingsRouterInput!
    var backgroundPersistence: BackgroundPersistence!
    var ruuviTagService: RuuviTagService!
    var errorPresenter: ErrorPresenter!
    var photoPickerPresenter: PhotoPickerPresenter! { didSet { photoPickerPresenter.delegate = self  } }
    var foreground: BTForeground!
    var background: BTBackground!
    var calibrationService: CalibrationService!
    var alertService: AlertService!
    var settings: Settings!
    
    private var ruuviTag: RuuviTagRealm! { didSet { syncViewModel() } }
    private var humidity: Double? { didSet { viewModel.relativeHumidity.value = humidity } }
    private var viewModel: TagSettingsViewModel! { didSet { view.viewModel = viewModel } }
    private var ruuviTagToken: NotificationToken?
    private var advertisementToken: ObservationToken?
    private var heartbeatToken: ObservationToken?
    private var temperatureUnitToken: NSObjectProtocol?
    
    deinit {
        ruuviTagToken?.invalidate()
        advertisementToken?.invalidate()
        heartbeatToken?.invalidate()
        if let temperatureUnitToken = temperatureUnitToken {
            NotificationCenter.default.removeObserver(temperatureUnitToken)
        }
    }
    
    func configure(ruuviTag: RuuviTagRealm, humidity: Double?) {
        self.viewModel = TagSettingsViewModel()
        self.ruuviTag = ruuviTag
        self.humidity = humidity
        startObservingRuuviTag()
        startScanningRuuviTag()
        startObservingSettingsChanges()
        bindViewModel()
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
    
    func viewDidAskToSelectBackground(sourceView: UIView) {
        photoPickerPresenter.pick(sourceView: sourceView)
    }
    
    func viewDidTapOnMacAddress() {
        if viewModel.mac.value != nil {
            view.showMacAddressDetail()
        } else {
            view.showUpdateFirmwareDialog()
        }
    }
    
    func viewDidTapOnUUID() {
        view.showUUIDDetail()
    }
    
    func viewDidAskToLearnMoreAboutFirmwareUpdate() {
        UIApplication.shared.open(URL(string: "https://lab.ruuvi.com/dfu")!)
    }
    
    func viewDidTapOnTxPower() {
        if viewModel.txPower.value == nil {
            view.showUpdateFirmwareDialog()
        }
    }
    
    func viewDidTapOnMovementCounter() {
        if viewModel.movementCounter.value == nil {
            view.showUpdateFirmwareDialog()
        }
    }
    
    func viewDidTapOnMeasurementSequenceNumber() {
        if viewModel.measurementSequenceNumber.value == nil {
            view.showUpdateFirmwareDialog()
        }
    }
    
    func viewDidTapOnNoValuesView() {
        view.showUpdateFirmwareDialog()
    }
    
    func viewDidTapOnHumidityAccessoryButton() {
        view.showHumidityIsClippedDialog()
    }
    
    func viewDidAskToFixHumidityAdjustment() {
        if let humidity = humidity {
            let operation = calibrationService.calibrateHumidityTo100Percent(currentValue: humidity, for: ruuviTag)
            operation.on(failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            })
        }
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
        viewModel.temperatureUnit.value = settings.temperatureUnit
        
        viewModel.background.value = backgroundPersistence.background(for: ruuviTag.uuid)
        
        if ruuviTag.name == ruuviTag.uuid || ruuviTag.name == ruuviTag.mac {
            viewModel.name.value = nil
        } else {
            viewModel.name.value = ruuviTag.name
        }
        
        viewModel.isConnectable.value = ruuviTag.isConnectable
        
        viewModel.mac.value = ruuviTag.mac
        viewModel.uuid.value = ruuviTag.uuid
        viewModel.version.value = ruuviTag.version
        
        viewModel.relativeHumidity.value = humidity
        viewModel.humidityOffset.value = ruuviTag.humidityOffset
        viewModel.humidityOffsetDate.value = ruuviTag.humidityOffsetDate
        
        viewModel.relativeHumidity.value = ruuviTag.data.last?.humidity.value
        
        viewModel.voltage.value = ruuviTag.data.last?.voltage.value
        viewModel.accelerationX.value = ruuviTag.data.last?.accelerationX.value
        viewModel.accelerationY.value = ruuviTag.data.last?.accelerationY.value
        viewModel.accelerationZ.value = ruuviTag.data.last?.accelerationZ.value
        
        // version 5 supports mc, msn, txPower
        if ruuviTag.version == 5 {
            viewModel.movementCounter.value = ruuviTag.data.last(where: { $0.movementCounter.value != nil })?.movementCounter.value
            viewModel.measurementSequenceNumber.value = ruuviTag.data.last(where: { $0.measurementSequenceNumber.value != nil })?.measurementSequenceNumber.value
            viewModel.txPower.value = ruuviTag.data.last(where: { $0.txPower.value != nil })?.txPower.value
        } else {
            viewModel.movementCounter.value = nil
            viewModel.measurementSequenceNumber.value = nil
            viewModel.txPower.value = nil
        }
        
        AlertType.allCases.forEach { (type) in
            switch type {
            case .temperature:
                if case .temperature(let lower, let upper) = alertService.alert(for: ruuviTag.uuid, of: type) {
                    viewModel.isTemperatureAlertOn.value = true
                    viewModel.celsiusLowerBound.value = lower
                    viewModel.celsiusUpperBound.value = upper
                } else {
                    viewModel.isTemperatureAlertOn.value = false
                    viewModel.celsiusLowerBound.value = alertService.lowerCelsius(for: ruuviTag.uuid)
                    viewModel.celsiusUpperBound.value = alertService.upperCelsius(for: ruuviTag.uuid)
                }
            }
        }
    }
    
    private func startObservingRuuviTag() {
        ruuviTagToken?.invalidate()
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
        advertisementToken?.invalidate()
        advertisementToken = foreground.observe(self, uuid: ruuviTag.uuid, closure: { [weak self] (observer, device) in
            if let tag = device.ruuvi?.tag {
                self?.sync(device: tag)
            }
        })
        heartbeatToken?.invalidate()
        heartbeatToken = background.observe(self, uuid: ruuviTag.uuid, closure: { [weak self] (observer, device) in
            if let tag = device.ruuvi?.tag {
                self?.sync(device: tag)
            }
        })
    }
    
    private func sync(device: RuuviTag) {
        humidity = device.humidity
        viewModel.voltage.value = device.voltage
        viewModel.accelerationX.value = device.accelerationX
        viewModel.accelerationY.value = device.accelerationY
        viewModel.accelerationZ.value = device.accelerationZ
        if viewModel.version.value != device.version {
            viewModel.version.value = device.version
        }
        if viewModel.isConnectable.value != device.isConnectable {
            viewModel.isConnectable.value = device.isConnectable
        }
        viewModel.movementCounter.value = device.movementCounter
        viewModel.measurementSequenceNumber.value = device.measurementSequenceNumber
        viewModel.txPower.value = device.txPower
        
        if let mac = device.mac {
            viewModel.mac.value = mac
        }
    }
    
    private func bindViewModel() {
        let temperatureLower = viewModel.celsiusLowerBound
        let temperatureUpper = viewModel.celsiusUpperBound
        bind(viewModel.isTemperatureAlertOn, fire: false) { [weak temperatureLower, weak temperatureUpper] observer, isOn in
            if let l = temperatureLower?.value, let u = temperatureUpper?.value {
                if isOn.bound {
                    observer.alertService.register(type: .temperature(lower: l, upper: u), for: observer.ruuviTag.uuid)
                } else {
                    observer.alertService.unregister(type: .temperature(lower: l, upper: u), for: observer.ruuviTag.uuid)
                }
            }
        }
        bind(viewModel.celsiusLowerBound, fire: false) { observer, lower in
            observer.alertService.setLower(celsius: lower, for: observer.ruuviTag.uuid)
        }
        bind(viewModel.celsiusUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpper(celsius: upper, for: observer.ruuviTag.uuid)
        }
    }
    
    private func startObservingSettingsChanges() {
        temperatureUnitToken = NotificationCenter.default.addObserver(forName: .TemperatureUnitDidChange, object: nil, queue: .main) { [weak self] (notification) in
            self?.viewModel.temperatureUnit.value = self?.settings.temperatureUnit
        }
    }
}
