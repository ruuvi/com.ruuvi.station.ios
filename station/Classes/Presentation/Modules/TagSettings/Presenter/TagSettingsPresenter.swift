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
    private var temperature: Temperature? {
        didSet {
            viewModel.temperature.value = temperature
        }
    }
    private var humidity: Humidity? {
        didSet {
            viewModel.humidity.value = humidity
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
    private var pressureUnitToken: NSObjectProtocol?
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
        pressureUnitToken?.invalidate()
        connectToken?.invalidate()
        disconnectToken?.invalidate()
        appDidBecomeActiveToken?.invalidate()
        alertDidChangeToken?.invalidate()
    }

    func configure(ruuviTag: RuuviTagSensor,
                   temperature: Temperature?,
                   humidity: Humidity?,
                   output: TagSettingsModuleOutput) {
        self.viewModel = TagSettingsViewModel()
        self.output = output
        self.temperature = temperature
        self.humidity = humidity
        self.ruuviTag = ruuviTag
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
            viewModel.background.value = backgroundPersistence.setNextDefaultBackground(for: macId)
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
            router.openHumidityCalibration(ruuviTag: ruuviTag, humidity: humidity.value)
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
            calibrationService.calibrateHumidityTo100Percent(currentValue: humidity.value, for: ruuviTag)
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
            set = backgroundPersistence.setCustomBackground(image: photo, for: macId)
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
        viewModel.pressureUnit.value = settings.pressureUnit

        if let luid = ruuviTag.luid {
            viewModel.background.value = backgroundPersistence.background(for: luid)
            viewModel.temperatureAlertDescription.value = alertService.temperatureDescription(for: luid.value)
            viewModel.humidityAlertDescription.value = alertService.humidityDescription(for: luid.value)
            viewModel.pressureAlertDescription.value = alertService.pressureDescription(for: luid.value)
            viewModel.connectionAlertDescription.value = alertService.connectionDescription(for: luid.value)
            viewModel.movementAlertDescription.value = alertService.movementDescription(for: luid.value)
        } else if let macId = ruuviTag.macId {
            viewModel.background.value = backgroundPersistence.background(for: macId)
            viewModel.temperatureAlertDescription.value = alertService.temperatureDescription(for: macId.value)
            viewModel.relativeHumidityAlertDescription.value
                = alertService.relativeHumidityDescription(for: macId.value)
            viewModel.absoluteHumidityAlertDescription.value
                = alertService.absoluteHumidityDescription(for: macId.value)
            viewModel.dewPointAlertDescription.value = alertService.dewPointDescription(for: macId.value)
            viewModel.pressureAlertDescription.value = alertService.pressureDescription(for: macId.value)
            viewModel.connectionAlertDescription.value = alertService.connectionDescription(for: macId.value)
            viewModel.movementAlertDescription.value = alertService.movementDescription(for: macId.value)
        } else {
            assertionFailure()
        }

        if ruuviTag.name == ruuviTag.luid?.value || ruuviTag.name == ruuviTag.macId?.value {
            viewModel.name.value = nil
        } else {
            viewModel.name.value = ruuviTag.name
        }

        viewModel.isConnectable.value = ruuviTag.isConnectable
        viewModel.isNetworkConnected.value = ruuviTag.any.isNetworkConnectable
        if let luid = ruuviTag.luid {
            viewModel.isConnected.value = background.isConnected(uuid: luid.value)
            viewModel.keepConnection.value = connectionPersistence.keepConnection(to: luid)
        } else {
            viewModel.isConnected.value = false
            viewModel.keepConnection.value = false
        }
        viewModel.mac.value = ruuviTag.macId?.mac
        viewModel.uuid.value = ruuviTag.luid?.value
        viewModel.version.value = ruuviTag.version
        syncAlerts()
    }

    private func syncAlerts() {
        if let identifier = ruuviTag.luid ?? ruuviTag.macId {
            AlertType.allCases.forEach { (type) in
                switch type {
                case .temperature:
                    sync(temperature: type, uuid: identifier.value)
                case .humidity:
                    sync(humidity: type, uuid: identifier.value)
                case .dewPoint:
                    sync(dewPoint: type, uuid: identifier.value)
                case .pressure:
                    sync(pressure: type, uuid: identifier.value)
                case .connection:
                    sync(connection: type, uuid: identifier.value)
                case .movement:
                    sync(movement: type, uuid: identifier.value)
                }
            }
        }
    }

    private func sync(temperature: AlertType, uuid: String) {
        if case .temperature(let lower, let upper) = alertService.alert(for: uuid, of: temperature) {
            viewModel.isTemperatureAlertOn.value = true
            viewModel.temperatureLowerBound.value = Temperature(Double(lower), unit: .celsius)
            viewModel.temperatureUpperBound.value = Temperature(Double(upper), unit: .celsius)
        } else {
            viewModel.isTemperatureAlertOn.value = false
            if let celsiusLower = alertService.lowerCelsius(for: uuid) {
                viewModel.temperatureLowerBound.value = Temperature(Double(celsiusLower), unit: .celsius)
            }
            if let celsiusUpper = alertService.upperCelsius(for: uuid) {
                viewModel.temperatureUpperBound.value = Temperature(Double(celsiusUpper), unit: .celsius)
            }
        }
    }

    private func sync(humidity: AlertType, uuid: String) {
        if case .humidity(let lower, let upper) = alertService.alert(for: uuid, of: humidity) {
            viewModel.isHumidityAlertOn.value = true
            if settings.humidityUnit == .gm3 {
                viewModel.humidityLowerBound.value = lower.converted(to: .absolute)
                viewModel.humidityUpperBound.value = upper.converted(to: .absolute)
            } else if let temp = viewModel.temperature.value {
                viewModel.humidityLowerBound.value = lower
                    .converted(to: .relative(temperature: temp))
                viewModel.humidityUpperBound.value = upper
                    .converted(to: .relative(temperature: temp))
            }
        } else {
            viewModel.isHumidityAlertOn.value = false
            if let humidityLower = alertService.lowerHumidity(for: uuid) {
                viewModel.humidityLowerBound.value = humidityLower
            }
            if let humidityUpper = alertService.upperHumidity(for: uuid) {
                viewModel.humidityUpperBound.value = humidityUpper
            }
        }
    }

    private func sync(dewPoint: AlertType, uuid: String) {
        if case .dewPoint(let lower, let upper) = alertService.alert(for: uuid, of: dewPoint) {
            viewModel.isDewPointAlertOn.value = true
            viewModel.dewPointLowerBound.value =  Temperature(Double(lower), unit: .celsius)
            viewModel.dewPointUpperBound.value =  Temperature(Double(upper), unit: .celsius)
        } else {
            viewModel.isDewPointAlertOn.value = false
            if let dewPointLowerBound = alertService.lowerDewPointCelsius(for: uuid) {
                viewModel.dewPointLowerBound.value = Temperature(Double(dewPointLowerBound), unit: .celsius)
            }
            if let dewPointUpperBound = alertService.upperDewPointCelsius(for: uuid) {
                viewModel.dewPointUpperBound.value = Temperature(Double(dewPointUpperBound), unit: .celsius)
            }
        }
    }

    private func sync(pressure: AlertType, uuid: String) {
        if case .pressure(let lower, let upper) = alertService.alert(for: uuid, of: pressure) {
            viewModel.isPressureAlertOn.value = true
            viewModel.pressureLowerBound.value = Pressure(Double(lower), unit: .hectopascals)
            viewModel.pressureUpperBound.value =  Pressure(Double(upper), unit: .hectopascals)
        } else {
            viewModel.isPressureAlertOn.value = false
            if let pressureLowerBound = alertService.lowerPressure(for: uuid) {
                viewModel.pressureLowerBound.value = Pressure(Double(pressureLowerBound), unit: .hectopascals)
            }
            if let pressureUpperBound = alertService.upperPressure(for: uuid) {
                viewModel.pressureUpperBound.value = Pressure(Double(pressureUpperBound), unit: .hectopascals)
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
        humidity = device.humidity
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
        if let identifier = ruuviTag.luid ?? ruuviTag.macId {
            if let luid = identifier as? LocalIdentifier {
                bind(viewModel.keepConnection, fire: false) { observer, keepConnection in
                    observer.connectionPersistence.setKeepConnection(keepConnection.bound, for: luid)
                }
            }
            bindTemperatureAlert(uuid: identifier.value)
            bindHumidityAlert(uuid: identifier.value)
            bindDewPoint(uuid: identifier.value)
            bindPressureAlert(uuid: identifier.value)
            bindConnectionAlert(uuid: identifier.value)
            bindMovementAlert(uuid: identifier.value)
            viewModel.isConnectable.value = identifier.value != ruuviTag.macId?.value
            viewModel.isNetworkConnected.value = ruuviTag.isNetworkConnectable
        }
    }

    private func bindTemperatureAlert(uuid: String) {
        let temperatureLower = viewModel.temperatureLowerBound
        let temperatureUpper = viewModel.temperatureUpperBound
        bind(viewModel.isTemperatureAlertOn, fire: false) {
            [weak temperatureLower,
             weak temperatureUpper] observer, isOn in
            if let l = temperatureLower?.value?.converted(to: .celsius).value,
               let u = temperatureUpper?.value?.converted(to: .celsius).value {
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
        bind(viewModel.temperatureLowerBound, fire: false) { observer, lower in
            if let l = lower?.converted(to: .celsius).value {
                observer.alertService.setLower(celsius: l, for: uuid)
            }
        }
        bind(viewModel.temperatureUpperBound, fire: false) { observer, upper in
            if let u = upper?.converted(to: .celsius).value {
                observer.alertService.setUpper(celsius: u, for: uuid)
            }
        }
        bind(viewModel.temperatureAlertDescription, fire: false) {observer, temperatureAlertDescription in
            observer.alertService.setTemperature(description: temperatureAlertDescription, for: uuid)
        }
    }

    private func bindHumidityAlert(uuid: String) {
        let humidityLower = viewModel.humidityLowerBound
        let humidityUpper = viewModel.humidityUpperBound
        bind(viewModel.isHumidityAlertOn, fire: false) {
            [weak humidityLower, weak humidityUpper] observer, isOn in
            if let l = humidityLower?.value,
               let u = humidityUpper?.value {
                let type: AlertType = .humidity(lower: l, upper: u)
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
        bind(viewModel.humidityLowerBound, fire: false) { observer, lower in
            observer.alertService.setLower(humidity: lower, for: uuid)
        }
        bind(viewModel.humidityUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpper(humidity: upper, for: uuid)
        }
        bind(viewModel.humidityAlertDescription, fire: false) { observer, humidityAlertDescription in
            observer.alertService.setHumidity(description: humidityAlertDescription, for: uuid)
        }
    }

    private func bindDewPoint(uuid: String) {
        let dewPointLower = viewModel.dewPointLowerBound
        let dewPointUpper = viewModel.dewPointUpperBound
        bind(viewModel.isDewPointAlertOn, fire: false) {
            [weak dewPointLower, weak dewPointUpper] observer, isOn in
            if let l = dewPointLower?.value?.converted(to: .celsius).value,
               let u = dewPointUpper?.value?.converted(to: .celsius).value {
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
        bind(viewModel.dewPointLowerBound, fire: false) { observer, lower in
            if let l = lower?.converted(to: .celsius).value {
                observer.alertService.setLowerDewPoint(celsius: l, for: uuid)
            }
        }
        bind(viewModel.dewPointUpperBound, fire: false) { observer, upper in
            if let u = upper?.converted(to: .celsius).value {
                observer.alertService.setUpperDewPoint(celsius: u, for: uuid)
            }
        }
        bind(viewModel.dewPointAlertDescription, fire: false) { observer, dewPointAlertDescription in
            observer.alertService.setDewPoint(description: dewPointAlertDescription, for: uuid)
        }
    }

    private func bindPressureAlert(uuid: String) {
        let pressureLower = viewModel.pressureLowerBound
        let pressureUpper = viewModel.pressureUpperBound
        bind(viewModel.isPressureAlertOn, fire: false) {
            [weak pressureLower, weak pressureUpper] observer, isOn in
            if let l = pressureLower?.value?.converted(to: .hectopascals).value,
               let u = pressureUpper?.value?.converted(to: .hectopascals).value {
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
            if let l = lower?.converted(to: .hectopascals).value {
                observer.alertService.setLower(pressure: l, for: uuid)
            }
        }

        bind(viewModel.pressureUpperBound, fire: false) { observer, upper in
            if let u = upper?.converted(to: .hectopascals).value {
                observer.alertService.setUpper(pressure: u, for: uuid)
            }
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
        pressureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .PressureUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
            self?.viewModel.pressureUnit.value = self?.settings.pressureUnit
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
        case .humidity:
            observable = viewModel.isHumidityAlertOn
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
