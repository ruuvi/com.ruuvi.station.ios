// swiftlint:disable file_length
import Foundation
import BTKit
import UIKit
import Future

class TagSettingsPresenter: NSObject, TagSettingsModuleInput {
    weak var view: TagSettingsViewInput!
    weak var output: TagSettingsModuleOutput!
    var router: TagSettingsRouterInput!
    var backgroundPersistence: BackgroundPersistence!
    var errorPresenter: ErrorPresenter!
    var photoPickerPresenter: PhotoPickerPresenter! {
        didSet {
            photoPickerPresenter.delegate = self
        }
    }
    var foreground: BTForeground!
    var background: BTBackground!
    var calibrationService: CalibrationService!
    var alertService: AlertService!
    var settings: Settings!
    var connectionPersistence: ConnectionPersistence!
    var pushNotificationsManager: PushNotificationsManager!
    var permissionPresenter: PermissionPresenter!
    var ruuviTagTank: RuuviTagTank!
    var ruuviTagTrunk: RuuviTagTrunk!
    var ruuviTagReactor: RuuviTagReactor!

    private var ruuviTag: RuuviTagSensor! {
        didSet {
            syncViewModel()
        }
    }
    private var humidity: Double? {
        didSet {
            viewModel.relativeHumidity.value = humidity
        }
    }
    private var viewModel: TagSettingsViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }
    private var ruuviTagToken: RUObservationToken?
    private var ruuviTagSensorRecordToken: RUObservationToken?
    private var advertisementToken: ObservationToken?
    private var heartbeatToken: ObservationToken?
    private var temperatureUnitToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
    private var connectToken: NSObjectProtocol?
    private var disconnectToken: NSObjectProtocol?
    private var appDidBecomeActiveToken: NSObjectProtocol?
    private var alertDidChangeToken: NSObjectProtocol?

    deinit {
        ruuviTagToken?.invalidate()
        ruuviTagSensorRecordToken?.invalidate()
        advertisementToken?.invalidate()
        heartbeatToken?.invalidate()
        temperatureUnitToken?.invalidate()
        humidityUnitToken?.invalidate()
        connectToken?.invalidate()
        disconnectToken?.invalidate()
        appDidBecomeActiveToken?.invalidate()
        alertDidChangeToken?.invalidate()
    }

    func configure(ruuviTag: RuuviTagSensor, humidity: Double?, output: TagSettingsModuleOutput) {
        self.viewModel = TagSettingsViewModel()
        self.output = output
        self.ruuviTag = ruuviTag
        self.humidity = humidity
        bindViewModel(to: ruuviTag)
        startObservingRuuviTag()
        startScanningRuuviTag()
        startObservingRuuviTagSensor(ruuviTag: ruuviTag)
        startObservingSettingsChanges()
        startObservingConnectionStatus()
        startObservingApplicationState()
        startObservingAlertChanges()
    }

    func dismiss(completion: (() -> Void)?) {
        router.dismiss(completion: completion)
    }
}

// MARK: - TagSettingsViewOutput
extension TagSettingsPresenter: TagSettingsViewOutput {

    func viewWillAppear() {
        checkPushNotificationsStatus()
    }

    func viewDidAskToDismiss() {
        router.dismiss()
    }

    func viewDidAskToRandomizeBackground() {
        if let luid = ruuviTag.luid {
            viewModel.background.value = backgroundPersistence.setNextDefaultBackground(for: luid)
        } else if let macId = ruuviTag.macId {
//            FIXME
//            viewModel.background.value = backgroundPersistence.setNextDefaultBackground(for: macId)
        } else {
            assertionFailure()
        }
    }

    func viewDidAskToRemoveRuuviTag() {
        view.showTagRemovalConfirmationDialog()
    }

    func viewDidConfirmTagRemoval() {
        if let isConnected = viewModel.isConnected.value,
            let keepConnection = viewModel.keepConnection.value,
            !isConnected && keepConnection {
            errorPresenter.present(error: RUError.expected(.failedToDeleteTag))
            return
        }
        let deleteTagOperation = ruuviTagTank.delete(ruuviTag)
        let deleteRecordsOperation = ruuviTagTank.deleteAllRecords(ruuviTag.id)
        Future.zip(deleteTagOperation, deleteRecordsOperation).on(success: { [weak self] _ in
            guard let sSelf = self else {
                return
            }
            sSelf.output.tagSettingsDidDeleteTag(module: sSelf, ruuviTag: sSelf.ruuviTag)
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }

    func viewDidChangeTag(name: String) {
        let finalName = name.isEmpty ? (ruuviTag.macId?.value ?? ruuviTag.id) : name
        var sensor = ruuviTag.struct
        sensor.name = finalName
        let operation = ruuviTagTank.update(sensor)
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
            calibrationService.calibrateHumidityTo100Percent(currentValue: humidity, for: ruuviTag)
        }
    }

    func viewDidTapOnAlertsDisabledView() {
        let isPN = viewModel.isPushNotificationsEnabled.value ?? false
        let isCo = viewModel.isConnected.value ?? false

        if !isPN && !isCo {
            view.showBothNotConnectedAndNoPNPermissionDialog()
        } else if !isPN {
            permissionPresenter.presentNoPushNotificationsPermission()
        } else if !isCo {
            view.showNotConnectedDialog()
        }
    }

    func viewDidAskToConnectFromAlertsDisabledDialog() {
        viewModel?.keepConnection.value = true
    }
}

// MARK: - PhotoPickerPresenterDelegate
extension TagSettingsPresenter: PhotoPickerPresenterDelegate {
    func photoPicker(presenter: PhotoPickerPresenter, didPick photo: UIImage) {
        let set: Future<URL, RUError>?
        if let luid = ruuviTag.luid {
            set = backgroundPersistence.setCustomBackground(image: photo, for: luid)
        } else if let macId = ruuviTag.macId {
            // FIXME
            // set = backgroundPersistence.setCustomBackground(image: photo, for: mac)
            set = nil
        } else {
            set = nil
            assertionFailure()
        }
        set?.on(success: { [weak self] _ in
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
        viewModel.humidityUnit.value = settings.humidityUnit

        if let luid = ruuviTag.luid {
            viewModel.background.value = backgroundPersistence.background(for: luid)
            viewModel.temperatureAlertDescription.value = alertService.temperatureDescription(for: luid.value)
            viewModel.relativeHumidityAlertDescription.value = alertService.relativeHumidityDescription(for: luid.value)
            viewModel.absoluteHumidityAlertDescription.value = alertService.absoluteHumidityDescription(for: luid.value)
            viewModel.dewPointAlertDescription.value = alertService.dewPointDescription(for: luid.value)
            viewModel.pressureAlertDescription.value = alertService.pressureDescription(for: luid.value)
            viewModel.connectionAlertDescription.value = alertService.connectionDescription(for: luid.value)
            viewModel.movementAlertDescription.value = alertService.movementDescription(for: luid.value)
        } else if let macId = ruuviTag.macId {
            // FIXME
            // viewModel.background.value = backgroundPersistence.background(for: mac)
//            viewModel.temperatureAlertDescription.value = alertService.temperatureDescription(for: macId)
//            viewModel.relativeHumidityAlertDescription.value = alertService.relativeHumidityDescription(for: macId)
//            viewModel.absoluteHumidityAlertDescription.value = alertService.absoluteHumidityDescription(for: macId)
//            viewModel.dewPointAlertDescription.value = alertService.dewPointDescription(for: macId)
//            viewModel.pressureAlertDescription.value = alertService.pressureDescription(for: macId)
//            viewModel.connectionAlertDescription.value = alertService.connectionDescription(for: macId)
//            viewModel.movementAlertDescription.value = alertService.movementDescription(for: macId)
        } else {
            assertionFailure()
        }

        if ruuviTag.name == ruuviTag.luid?.value || ruuviTag.name == ruuviTag.macId?.value {
            viewModel.name.value = nil
        } else {
            viewModel.name.value = ruuviTag.name
        }

        viewModel.isConnectable.value = ruuviTag.isConnectable
        if let luid = ruuviTag.luid {
            viewModel.isConnected.value = background.isConnected(uuid: luid.value)
            viewModel.keepConnection.value = connectionPersistence.keepConnection(to: luid)
        } else {
            viewModel.isConnected.value = false
            viewModel.keepConnection.value = false
        }

        viewModel.mac.value = ruuviTag.macId?.value
        viewModel.uuid.value = ruuviTag.luid?.value
        viewModel.version.value = ruuviTag.version
        syncAlerts()
    }

    private func syncAlerts() {
        if let luid = ruuviTag.luid {
            AlertType.allCases.forEach { (type) in
                switch type {
                case .temperature:
                    sync(temperature: type, uuid: luid.value)
                case .relativeHumidity:
                    sync(relativeHumidity: type, uuid: luid.value)
                case .absoluteHumidity:
                    sync(abosluteHumidity: type, uuid: luid.value)
                case .dewPoint:
                    sync(dewPoint: type, uuid: luid.value)
                case .pressure:
                    sync(pressure: type, uuid: luid.value)
                case .connection:
                    sync(connection: type, uuid: luid.value)
                case .movement:
                    sync(movement: type, uuid: luid.value)
                }
            }
        } else {
            // FIXME
        }
    }

    private func sync(temperature: AlertType, uuid: String) {
        if case .temperature(let lower, let upper) = alertService.alert(for: uuid, of: temperature) {
            viewModel.isTemperatureAlertOn.value = true
            viewModel.celsiusLowerBound.value = lower
            viewModel.celsiusUpperBound.value = upper
        } else {
            viewModel.isTemperatureAlertOn.value = false
            if let celsiusLower = alertService.lowerCelsius(for: uuid) {
                viewModel.celsiusLowerBound.value = celsiusLower
            }
            if let celsiusUpper = alertService.upperCelsius(for: uuid) {
                viewModel.celsiusUpperBound.value = celsiusUpper
            }
        }
    }

    private func sync(relativeHumidity: AlertType, uuid: String) {
        if case .relativeHumidity(let lower, let upper) = alertService.alert(for: uuid, of: relativeHumidity) {
            viewModel.isRelativeHumidityAlertOn.value = true
            viewModel.relativeHumidityLowerBound.value = lower
            viewModel.relativeHumidityUpperBound.value = upper
        } else {
            viewModel.isRelativeHumidityAlertOn.value = false
            if let realtiveHumidityLower = alertService.lowerRelativeHumidity(for: uuid) {
                viewModel.relativeHumidityLowerBound.value = realtiveHumidityLower
            }
            if let relativeHumidityUpper = alertService.upperRelativeHumidity(for: uuid) {
                viewModel.relativeHumidityUpperBound.value = relativeHumidityUpper
            }
        }
    }

    private func sync(abosluteHumidity: AlertType, uuid: String) {
        if case .absoluteHumidity(let lower, let upper) = alertService.alert(for: uuid, of: abosluteHumidity) {
            viewModel.isAbsoluteHumidityAlertOn.value = true
            viewModel.absoluteHumidityLowerBound.value = lower
            viewModel.absoluteHumidityUpperBound.value = upper
        } else {
            viewModel.isAbsoluteHumidityAlertOn.value = false
            if let absoluteHumidityLower = alertService.lowerAbsoluteHumidity(for: uuid) {
                viewModel.absoluteHumidityLowerBound.value = absoluteHumidityLower
            }
            if let absoluteHumidityUpper = alertService.upperAbsoluteHumidity(for: uuid) {
                viewModel.absoluteHumidityUpperBound.value = absoluteHumidityUpper
            }
        }
    }

    private func sync(dewPoint: AlertType, uuid: String) {
        if case .dewPoint(let lower, let upper) = alertService.alert(for: uuid, of: dewPoint) {
            viewModel.isDewPointAlertOn.value = true
            viewModel.dewPointCelsiusLowerBound.value = lower
            viewModel.dewPointCelsiusUpperBound.value = upper
        } else {
            viewModel.isDewPointAlertOn.value = false
            if let dewPointCelsiusLowerBound = alertService.lowerDewPointCelsius(for: uuid) {
                viewModel.dewPointCelsiusLowerBound.value = dewPointCelsiusLowerBound
            }
            if let dewPointCelsiusUpperBound = alertService.upperDewPointCelsius(for: uuid) {
                viewModel.dewPointCelsiusUpperBound.value = dewPointCelsiusUpperBound
            }
        }
    }

    private func sync(pressure: AlertType, uuid: String) {
        if case .pressure(let lower, let upper) = alertService.alert(for: uuid, of: pressure) {
            viewModel.isPressureAlertOn.value = true
            viewModel.pressureLowerBound.value = lower
            viewModel.pressureUpperBound.value = upper
        } else {
            viewModel.isPressureAlertOn.value = false
            if let pressureLowerBound = alertService.lowerPressure(for: uuid) {
                viewModel.pressureLowerBound.value = pressureLowerBound
            }
            if let pressureUpperBound = alertService.upperPressure(for: uuid) {
                viewModel.pressureUpperBound.value = pressureUpperBound
            }
        }
    }

    private func sync(connection: AlertType, uuid: String) {
        if case .connection = alertService.alert(for: uuid, of: connection) {
            viewModel.isConnectionAlertOn.value = true
        } else {
            viewModel.isConnectionAlertOn.value = false
        }
    }

    private func sync(movement: AlertType, uuid: String) {
        if case .movement = alertService.alert(for: uuid, of: movement) {
            viewModel.isMovementAlertOn.value = true
        } else {
            viewModel.isMovementAlertOn.value = false
        }
    }

    private func startObservingRuuviTag() {
        ruuviTagToken?.invalidate()
        ruuviTagToken = ruuviTagReactor.observe { [weak self] (change) in
            switch change {
            case .error(let error):
                self?.errorPresenter.present(error: error)
            default:
                return
            }
        }
    }

    private func startObservingRuuviTagSensor(ruuviTag: RuuviTagSensor) {
        ruuviTagSensorRecordToken?.invalidate()
        ruuviTagSensorRecordToken = ruuviTagReactor.observeLast(ruuviTag, { [weak self] (changes) in
            switch changes {
            case .update(let record):
                if let lastRecord = record {
                    self?.viewModel.updateRecord(lastRecord)
                }
            case .error(let error):
                self?.errorPresenter.present(error: error)
            default:
                break
            }
        })
    }
    private func startScanningRuuviTag() {
        advertisementToken?.invalidate()
        guard let luid = ruuviTag.luid else {
            return
        }
        advertisementToken = foreground.observe(self, uuid: luid.value, closure: { [weak self] (_, device) in
            if let tag = device.ruuvi?.tag {
                self?.sync(device: tag)
            }
        })
        heartbeatToken?.invalidate()
        heartbeatToken = background.observe(self, uuid: luid.value, closure: { [weak self] (_, device) in
            if let tag = device.ruuvi?.tag {
                self?.sync(device: tag)
            }
        })
    }

    private func sync(device: RuuviTag) {
        humidity = device.relativeHumidity
        let record = RuuviTagSensorRecordStruct(ruuviTagId: device.ruuviTagId,
                                                date: device.date,
                                                macId: device.mac?.mac,
                                                rssi: device.rssi,
                                                temperature: device.temperature,
                                                humidity: device.humidity,
                                                pressure: device.pressure,
                                                acceleration: device.acceleration,
                                                voltage: device.voltage,
                                                movementCounter: device.movementCounter,
                                                measurementSequenceNumber: device.measurementSequenceNumber,
                                                txPower: device.txPower)
        if viewModel.version.value != device.version {
            viewModel.version.value = device.version
        }
        if viewModel.isConnectable.value != device.isConnectable {
            viewModel.isConnectable.value = device.isConnectable
        }
        if viewModel.isConnected.value != device.isConnected {
            viewModel.isConnected.value = device.isConnected
        }
        if let mac = device.mac {
            viewModel.mac.value = mac
        }
        viewModel.updateRecord(record)
    }

    private func bindViewModel(to ruuviTag: RuuviTagSensor) {
        if let luid = ruuviTag.luid {
            bind(viewModel.keepConnection, fire: false) { observer, keepConnection in
                observer.connectionPersistence.setKeepConnection(keepConnection.bound, for: luid)
            }
            bindTemperatureAlert(uuid: luid.value)
            bindRelativeHumidityAlert(uuid: luid.value)
            bindAbsoluteHumidityAlert(uuid: luid.value)
            bindDewPoint(uuid: luid.value)
            bindPressureAlert(uuid: luid.value)
            bindConnectionAlert(uuid: luid.value)
            bindMovementAlert(uuid: luid.value)
        } else {
            //FIXME
        }
    }

    private func bindAbsoluteHumidityAlert(uuid: String) {
        let absoluteHumidityLower = viewModel.absoluteHumidityLowerBound
        let absoluteHumidityUpper = viewModel.absoluteHumidityUpperBound
        bind(viewModel.isAbsoluteHumidityAlertOn, fire: false) {
            [weak absoluteHumidityLower, weak absoluteHumidityUpper] observer, isOn in
            if let l = absoluteHumidityLower?.value, let u = absoluteHumidityUpper?.value {
                let type: AlertType = .absoluteHumidity(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: uuid)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: uuid)
                    } else {
                        observer.alertService.unregister(type: type, for: uuid)
                    }
                }
            }
        }

        bind(viewModel.absoluteHumidityLowerBound, fire: false) { observer, lower in
            observer.alertService.setLower(absoluteHumidity: lower, for: uuid)
        }

        bind(viewModel.absoluteHumidityUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpper(absoluteHumidity: upper, for: uuid)
        }

        bind(viewModel.absoluteHumidityAlertDescription, fire: false) { observer, absoluteHumidityAlertDescription in
            observer.alertService.setAbsoluteHumidity(description: absoluteHumidityAlertDescription, for: uuid)
        }
    }

    private func bindDewPoint(uuid: String) {
        let dewPointLower = viewModel.dewPointCelsiusLowerBound
        let dewPointUpper = viewModel.dewPointCelsiusUpperBound
        bind(viewModel.isDewPointAlertOn, fire: false) {
            [weak dewPointLower, weak dewPointUpper] observer, isOn in
            if let l = dewPointLower?.value, let u = dewPointUpper?.value {
                let type: AlertType = .dewPoint(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: uuid)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: uuid)
                    } else {
                        observer.alertService.unregister(type: type, for: uuid)
                    }
                }
            }
        }
        bind(viewModel.dewPointCelsiusLowerBound, fire: false) { observer, lower in
            observer.alertService.setLowerDewPoint(celsius: lower, for: uuid)
        }
        bind(viewModel.dewPointCelsiusUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpperDewPoint(celsius: upper, for: uuid)
        }
        bind(viewModel.dewPointAlertDescription, fire: false) { observer, dewPointAlertDescription in
            observer.alertService.setDewPoint(description: dewPointAlertDescription, for: uuid)
        }
    }

    private func bindTemperatureAlert(uuid: String) {
        let temperatureLower = viewModel.celsiusLowerBound
        let temperatureUpper = viewModel.celsiusUpperBound
        bind(viewModel.isTemperatureAlertOn, fire: false) {
            [weak temperatureLower, weak temperatureUpper] observer, isOn in
            if let l = temperatureLower?.value, let u = temperatureUpper?.value {
                let type: AlertType = .temperature(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: uuid)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: uuid)
                    } else {
                        observer.alertService.unregister(type: type, for: uuid)
                    }
                }
            }
        }
        bind(viewModel.celsiusLowerBound, fire: false) { observer, lower in
            observer.alertService.setLower(celsius: lower, for: uuid)
        }
        bind(viewModel.celsiusUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpper(celsius: upper, for: uuid)
        }
        bind(viewModel.temperatureAlertDescription, fire: false) {observer, temperatureAlertDescription in
            observer.alertService.setTemperature(description: temperatureAlertDescription, for: uuid)
        }
    }

    private func bindRelativeHumidityAlert(uuid: String) {
        let relativeHumidityLower = viewModel.relativeHumidityLowerBound
        let relativeHumidityUpper = viewModel.relativeHumidityUpperBound
        bind(viewModel.isRelativeHumidityAlertOn, fire: false) {
            [weak relativeHumidityLower, weak relativeHumidityUpper] observer, isOn in
            if let l = relativeHumidityLower?.value, let u = relativeHumidityUpper?.value {
                let type: AlertType = .relativeHumidity(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: uuid)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: uuid)
                    } else {
                        observer.alertService.unregister(type: type, for: uuid)
                    }
                }
            }
        }
        bind(viewModel.relativeHumidityLowerBound, fire: false) { observer, lower in
            observer.alertService.setLower(relativeHumidity: lower, for: uuid)
        }
        bind(viewModel.relativeHumidityUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpper(relativeHumidity: upper, for: uuid)
        }
        bind(viewModel.relativeHumidityAlertDescription, fire: false) { observer, relativeHumidityAlertDescription in
            observer.alertService.setRelativeHumidity(description: relativeHumidityAlertDescription, for: uuid)
        }
    }

    private func bindPressureAlert(uuid: String) {
        let pressureLower = viewModel.pressureLowerBound
        let pressureUpper = viewModel.pressureUpperBound
        bind(viewModel.isPressureAlertOn, fire: false) {
            [weak pressureLower, weak pressureUpper] observer, isOn in
            if let l = pressureLower?.value, let u = pressureUpper?.value {
                let type: AlertType = .pressure(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: uuid)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: uuid)
                    } else {
                        observer.alertService.unregister(type: type, for: uuid)
                    }
                }
            }
        }

        bind(viewModel.pressureLowerBound, fire: false) { observer, lower in
            observer.alertService.setLower(pressure: lower, for: uuid)
        }

        bind(viewModel.pressureUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpper(pressure: upper, for: uuid)
        }

        bind(viewModel.pressureAlertDescription, fire: false) { observer, pressureAlertDescription in
            observer.alertService.setPressure(description: pressureAlertDescription, for: uuid)
        }
    }

    private func bindConnectionAlert(uuid: String) {
        bind(viewModel.isConnectionAlertOn, fire: false) { observer, isOn in
            let type: AlertType = .connection
            let currentState = observer.alertService.isOn(type: type, for: uuid)
            if currentState != isOn.bound {
                if isOn.bound {
                    observer.alertService.register(type: type, for: uuid)
                } else {
                    observer.alertService.unregister(type: type, for: uuid)
                }
            }
        }

        bind(viewModel.connectionAlertDescription, fire: false) { observer, connectionAlertDescription in
            observer.alertService.setConnection(description: connectionAlertDescription, for: uuid)
        }
    }

    private func bindMovementAlert(uuid: String) {
        bind(viewModel.isMovementAlertOn, fire: false) {[weak self] observer, isOn in
            guard let strongSelf = self else {
                return
            }
            observer.ruuviTagTrunk.readLast(strongSelf.ruuviTag).on(success: { record in
                let last = record?.movementCounter ?? 0
                let type: AlertType = .movement(last: last)
                let currentState = observer.alertService.isOn(type: type, for: uuid)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: uuid)
                    } else {
                        observer.alertService.unregister(type: type, for: uuid)
                    }
                }
            }, failure: { error in
                observer.errorPresenter.present(error: error)
            })
        }
        bind(viewModel.movementAlertDescription, fire: false) { observer, movementAlertDescription in
            observer.alertService.setMovement(description: movementAlertDescription, for: uuid)
        }
    }

    private func startObservingSettingsChanges() {
        temperatureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .TemperatureUnitDidChange,
                         object: nil,
                         queue: .main) { [weak self] _ in
            self?.viewModel.temperatureUnit.value = self?.settings.temperatureUnit
        }
        humidityUnitToken = NotificationCenter
            .default
            .addObserver(forName: .HumidityUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
            self?.viewModel.humidityUnit.value = self?.settings.humidityUnit
        })
    }

    private func startObservingConnectionStatus() {
        connectToken = NotificationCenter
            .default
            .addObserver(forName: .BTBackgroundDidConnect,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
            if let userInfo = notification.userInfo,
                let uuid = userInfo[BTBackgroundDidConnectKey.uuid] as? String,
                            uuid == self?.ruuviTag.luid?.value {
                self?.viewModel.isConnected.value = true
            }
        })

        disconnectToken = NotificationCenter
            .default
            .addObserver(forName: .BTBackgroundDidDisconnect,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
            if let userInfo = notification.userInfo,
                let uuid = userInfo[BTBackgroundDidDisconnectKey.uuid] as? String,
                            uuid == self?.ruuviTag.luid?.value {
                self?.viewModel.isConnected.value = false
            }
        })
    }

    private func startObservingApplicationState() {
        appDidBecomeActiveToken = NotificationCenter
            .default
            .addObserver(forName: UIApplication.didBecomeActiveNotification,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (_) in
            self?.checkPushNotificationsStatus()
        })
    }

    private func checkPushNotificationsStatus() {
        pushNotificationsManager.getRemoteNotificationsAuthorizationStatus { [weak self] (status) in
            switch status {
            case .notDetermined:
                self?.pushNotificationsManager.registerForRemoteNotifications()
            case .authorized:
                self?.viewModel.isPushNotificationsEnabled.value = true
            case .denied:
                self?.viewModel.isPushNotificationsEnabled.value = false
            }
        }
    }

    private func startObservingAlertChanges() {
        alertDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .AlertServiceAlertDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
            if let userInfo = notification.userInfo,
                let uuid = userInfo[AlertServiceAlertDidChangeKey.uuid] as? String,
                uuid == self?.viewModel.uuid.value,
                let type = userInfo[AlertServiceAlertDidChangeKey.type] as? AlertType {
                self?.updateIsOnState(of: type, for: uuid)
            }
        })
    }

    private func updateIsOnState(of type: AlertType, for uuid: String) {
        var observable: Observable<Bool?>
        switch type {
        case .temperature:
            observable = viewModel.isTemperatureAlertOn
        case .relativeHumidity:
            observable = viewModel.isRelativeHumidityAlertOn
        case .absoluteHumidity:
            observable = viewModel.isAbsoluteHumidityAlertOn
        case .dewPoint:
            observable = viewModel.isDewPointAlertOn
        case .pressure:
            observable = viewModel.isPressureAlertOn
        case .connection:
            observable = viewModel.isConnectionAlertOn
        case .movement:
            observable = viewModel.isMovementAlertOn
        }

        let isOn = alertService.isOn(type: type, for: uuid)
        if isOn != observable.value {
            observable.value = isOn
        }
    }
}
// swiftlint:enable file_length
