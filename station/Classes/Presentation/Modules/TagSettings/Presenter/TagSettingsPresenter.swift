// swiftlint:disable file_length
import Foundation
import RealmSwift
import BTKit
import UIKit

class TagSettingsPresenter: NSObject, TagSettingsModuleInput {
    weak var view: TagSettingsViewInput!
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
        advertisementToken?.invalidate()
        heartbeatToken?.invalidate()
        if let temperatureUnitToken = temperatureUnitToken {
            NotificationCenter.default.removeObserver(temperatureUnitToken)
        }
        if let humidityUnitToken = humidityUnitToken {
            NotificationCenter.default.removeObserver(humidityUnitToken)
        }
        if let connectToken = connectToken {
            NotificationCenter.default.removeObserver(connectToken)
        }
        if let disconnectToken = disconnectToken {
            NotificationCenter.default.removeObserver(disconnectToken)
        }
        if let appDidBecomeActiveToken = appDidBecomeActiveToken {
            NotificationCenter.default.removeObserver(appDidBecomeActiveToken)
        }
        if let alertDidChangeToken = alertDidChangeToken {
            NotificationCenter.default.removeObserver(alertDidChangeToken)
        }
    }

    func configure(ruuviTag: RuuviTagSensor, humidity: Double?) {
        self.viewModel = TagSettingsViewModel()
        self.ruuviTag = ruuviTag
        self.humidity = humidity
        bindViewModel(to: ruuviTag)
        startObservingRuuviTag()
        startScanningRuuviTag()
        startObservingSettingsChanges()
        startObservingConnectionStatus()
        startObservingApplicationState()
        startObservingAlertChanges()
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
        viewModel.background.value = backgroundPersistence.setNextDefaultBackground(for: ruuviTag.id)
    }

    func viewDidAskToRemoveRuuviTag() {
        view.showTagRemovalConfirmationDialog()
    }

    func viewDidConfirmTagRemoval() {
        if let isConnected = viewModel.isConnected.value,
            let keepConnection = viewModel.keepConnection.value,
            !isConnected && keepConnection {
            self.errorPresenter.present(error: RUError.expected(.failedToDeleteTag))
            return
        }
        let operation = ruuviTagTank.delete(ruuviTag)
        operation.on(success: { [weak self] _ in
            self?.router.dismiss()
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }

    func viewDidChangeTag(name: String) {
        let finalName = name.isEmpty ? (ruuviTag.mac ?? ruuviTag.id) : name
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
//            let operation = calibrationService.calibrateHumidityTo100Percent(currentValue: humidity, for: ruuviTag) TODO
//            operation.on(failure: { [weak self] (error) in
//                self?.errorPresenter.present(error: error)
//            })
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
        let set = backgroundPersistence.setCustomBackground(image: photo, for: ruuviTag.id)
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
        viewModel.humidityUnit.value = settings.humidityUnit
        viewModel.temperatureAlertDescription.value = alertService.temperatureDescription(for: ruuviTag.id)
        viewModel.relativeHumidityAlertDescription.value = alertService.relativeHumidityDescription(for: ruuviTag.id)
        viewModel.absoluteHumidityAlertDescription.value = alertService.absoluteHumidityDescription(for: ruuviTag.id)
        viewModel.dewPointAlertDescription.value = alertService.dewPointDescription(for: ruuviTag.id)
        viewModel.pressureAlertDescription.value = alertService.pressureDescription(for: ruuviTag.id)
        viewModel.connectionAlertDescription.value = alertService.connectionDescription(for: ruuviTag.id)
        viewModel.movementAlertDescription.value = alertService.movementDescription(for: ruuviTag.id)

        viewModel.background.value = backgroundPersistence.background(for: ruuviTag.id)

        if ruuviTag.name == ruuviTag.luid || ruuviTag.name == ruuviTag.mac {
            viewModel.name.value = nil
        } else {
            viewModel.name.value = ruuviTag.name
        }

        viewModel.isConnectable.value = ruuviTag.isConnectable
        if let uuid = ruuviTag.luid {
            viewModel.isConnected.value = background.isConnected(uuid: uuid)
            viewModel.keepConnection.value = connectionPersistence.keepConnection(to: uuid)
        } else {
            viewModel.isConnected.value = false
            viewModel.keepConnection.value = false
        }

        viewModel.mac.value = ruuviTag.mac
        viewModel.uuid.value = ruuviTag.luid ?? ruuviTag.id
        viewModel.version.value = ruuviTag.version

        viewModel.relativeHumidity.value = humidity
//        viewModel.humidityOffset.value = ruuviTag.humidityOffset TODO
//        viewModel.humidityOffsetDate.value = ruuviTag.humidityOffsetDate TODO

//        viewModel.relativeHumidity.value = ruuviTag.data.last?.humidity.value TODO
//        viewModel.voltage.value = ruuviTag.data.last?.voltage.value TODO
//        viewModel.accelerationX.value = ruuviTag.data.last?.accelerationX.value TODO
//        viewModel.accelerationY.value = ruuviTag.data.last?.accelerationY.value TODO
//        viewModel.accelerationZ.value = ruuviTag.data.last?.accelerationZ.value TODO

        // version 5 supports mc, msn, txPower
//        if ruuviTag.version == 5 {
//            viewModel.movementCounter.value = ruuviTag.data
//                .last(where: { $0.movementCounter.value != nil })?.movementCounter.value
//            viewModel.measurementSequenceNumber.value = ruuviTag.data
//                .last(where: { $0.measurementSequenceNumber.value != nil })?.measurementSequenceNumber.value
//            viewModel.txPower.value = ruuviTag.data.last(where: { $0.txPower.value != nil })?.txPower.value
//        } else {
//            viewModel.movementCounter.value = nil
//            viewModel.measurementSequenceNumber.value = nil
//            viewModel.txPower.value = nil
//        }

        syncAlerts()
    }

    private func syncAlerts() {
        AlertType.allCases.forEach { (type) in
            switch type {
            case .temperature:
                sync(temperature: type)
            case .relativeHumidity:
                sync(relativeHumidity: type)
            case .absoluteHumidity:
                sync(abosluteHumidity: type)
            case .dewPoint:
                sync(dewPoint: type)
            case .pressure:
                sync(pressure: type)
            case .connection:
                sync(connection: type)
            case .movement:
                sync(movement: type)
            }
        }
    }

    private func sync(temperature: AlertType) {
        if case .temperature(let lower, let upper) = alertService.alert(for: ruuviTag.id, of: temperature) {
            viewModel.isTemperatureAlertOn.value = true
            viewModel.celsiusLowerBound.value = lower
            viewModel.celsiusUpperBound.value = upper
        } else {
            viewModel.isTemperatureAlertOn.value = false
            if let celsiusLower = alertService.lowerCelsius(for: ruuviTag.id) {
                viewModel.celsiusLowerBound.value = celsiusLower
            }
            if let celsiusUpper = alertService.upperCelsius(for: ruuviTag.id) {
                viewModel.celsiusUpperBound.value = celsiusUpper
            }
        }
    }

    private func sync(relativeHumidity: AlertType) {
        if case .relativeHumidity(let lower, let upper) = alertService.alert(for: ruuviTag.id, of: relativeHumidity) {
            viewModel.isRelativeHumidityAlertOn.value = true
            viewModel.relativeHumidityLowerBound.value = lower
            viewModel.relativeHumidityUpperBound.value = upper
        } else {
            viewModel.isRelativeHumidityAlertOn.value = false
            if let realtiveHumidityLower = alertService.lowerRelativeHumidity(for: ruuviTag.id) {
                viewModel.relativeHumidityLowerBound.value = realtiveHumidityLower
            }
            if let relativeHumidityUpper = alertService.upperRelativeHumidity(for: ruuviTag.id) {
                viewModel.relativeHumidityUpperBound.value = relativeHumidityUpper
            }
        }
    }

    private func sync(abosluteHumidity: AlertType) {
        if case .absoluteHumidity(let lower, let upper) = alertService.alert(for: ruuviTag.id, of: abosluteHumidity) {
            viewModel.isAbsoluteHumidityAlertOn.value = true
            viewModel.absoluteHumidityLowerBound.value = lower
            viewModel.absoluteHumidityUpperBound.value = upper
        } else {
            viewModel.isAbsoluteHumidityAlertOn.value = false
            if let absoluteHumidityLower = alertService.lowerAbsoluteHumidity(for: ruuviTag.id) {
                viewModel.absoluteHumidityLowerBound.value = absoluteHumidityLower
            }
            if let absoluteHumidityUpper = alertService.upperAbsoluteHumidity(for: ruuviTag.id) {
                viewModel.absoluteHumidityUpperBound.value = absoluteHumidityUpper
            }
        }
    }

    private func sync(dewPoint: AlertType) {
        if case .dewPoint(let lower, let upper) = alertService.alert(for: ruuviTag.id, of: dewPoint) {
            viewModel.isDewPointAlertOn.value = true
            viewModel.dewPointCelsiusLowerBound.value = lower
            viewModel.dewPointCelsiusUpperBound.value = upper
        } else {
            viewModel.isDewPointAlertOn.value = false
            if let dewPointCelsiusLowerBound = alertService.lowerDewPointCelsius(for: ruuviTag.id) {
                viewModel.dewPointCelsiusLowerBound.value = dewPointCelsiusLowerBound
            }
            if let dewPointCelsiusUpperBound = alertService.upperDewPointCelsius(for: ruuviTag.id) {
                viewModel.dewPointCelsiusUpperBound.value = dewPointCelsiusUpperBound
            }
        }
    }

    private func sync(pressure: AlertType) {
        if case .pressure(let lower, let upper) = alertService.alert(for: ruuviTag.id, of: pressure) {
            viewModel.isPressureAlertOn.value = true
            viewModel.pressureLowerBound.value = lower
            viewModel.pressureUpperBound.value = upper
        } else {
            viewModel.isPressureAlertOn.value = false
            if let pressureLowerBound = alertService.lowerPressure(for: ruuviTag.id) {
                viewModel.pressureLowerBound.value = pressureLowerBound
            }
            if let pressureUpperBound = alertService.upperPressure(for: ruuviTag.id) {
                viewModel.pressureUpperBound.value = pressureUpperBound
            }
        }
    }

    private func sync(connection: AlertType) {
        if case .connection = alertService.alert(for: ruuviTag.id, of: connection) {
            viewModel.isConnectionAlertOn.value = true
        } else {
            viewModel.isConnectionAlertOn.value = false
        }
    }

    private func sync(movement: AlertType) {
        if case .movement = alertService.alert(for: ruuviTag.id, of: movement) {
            viewModel.isMovementAlertOn.value = true
        } else {
            viewModel.isMovementAlertOn.value = false
        }
    }

    private func startObservingRuuviTag() {
//        ruuviTagToken?.invalidate() TODO
//        ruuviTagToken = ruuviTagReactor.observe { [weak self] (change) in
//            switch change {
//            case .change:
//                self?.syncViewModel()
//            case .deleted:
//                self?.router.dismiss()
//            case .error(let error):
//                self?.errorPresenter.present(error: error)
//            }
//        }
    }

    private func startScanningRuuviTag() {
        advertisementToken?.invalidate()
        advertisementToken = foreground.observe(self, uuid: ruuviTag.id, closure: { [weak self] (_, device) in
            if let tag = device.ruuvi?.tag {
                self?.sync(device: tag)
            }
        })
        heartbeatToken?.invalidate()
        heartbeatToken = background.observe(self, uuid: ruuviTag.id, closure: { [weak self] (_, device) in
            if let tag = device.ruuvi?.tag {
                self?.sync(device: tag)
            }
        })
    }

    private func sync(device: RuuviTag) {
        humidity = device.relativeHumidity
        viewModel.voltage.value = device.volts
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
        if viewModel.isConnected.value != device.isConnected {
            viewModel.isConnected.value = device.isConnected
        }

        if let mac = device.mac {
            viewModel.mac.value = mac
        }
    }

    private func bindViewModel(to ruuviTag: RuuviTagSensor) {
        bind(viewModel.keepConnection, fire: false) { observer, keepConnection in
            if let uuid = ruuviTag.luid {
                observer.connectionPersistence.setKeepConnection(keepConnection.bound, for: uuid)
            }
        }

        bindTemperatureAlert(ruuviTag)
        bindRelativeHumidityAlert(ruuviTag)
        bindAbsoluteHumidityAlert(ruuviTag)
        bindDewPoint(ruuviTag)
        bindPressureAlert(ruuviTag)
        bindConnectionAlert(ruuviTag)
        bindMovementAlert(ruuviTag)
    }

    private func bindAbsoluteHumidityAlert(_ ruuviTag: RuuviTagSensor) {
        let absoluteHumidityLower = viewModel.absoluteHumidityLowerBound
        let absoluteHumidityUpper = viewModel.absoluteHumidityUpperBound
        bind(viewModel.isAbsoluteHumidityAlertOn, fire: false) {
            [weak absoluteHumidityLower, weak absoluteHumidityUpper] observer, isOn in
            if let l = absoluteHumidityLower?.value, let u = absoluteHumidityUpper?.value {
                let type: AlertType = .absoluteHumidity(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: ruuviTag.id)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: ruuviTag.id)
                    } else {
                        observer.alertService.unregister(type: type, for: ruuviTag.id)
                    }
                }
            }
        }

        bind(viewModel.absoluteHumidityLowerBound, fire: false) { observer, lower in
            observer.alertService.setLower(absoluteHumidity: lower, for: ruuviTag.id)
        }

        bind(viewModel.absoluteHumidityUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpper(absoluteHumidity: upper, for: ruuviTag.id)
        }

        bind(viewModel.absoluteHumidityAlertDescription, fire: false) { observer, absoluteHumidityAlertDescription in
            observer.alertService.setAbsoluteHumidity(description: absoluteHumidityAlertDescription, for: ruuviTag.id)
        }
    }

    private func bindDewPoint(_ ruuviTag: RuuviTagSensor) {
        let dewPointLower = viewModel.dewPointCelsiusLowerBound
        let dewPointUpper = viewModel.dewPointCelsiusUpperBound
        bind(viewModel.isDewPointAlertOn, fire: false) {
            [weak dewPointLower, weak dewPointUpper] observer, isOn in
            if let l = dewPointLower?.value, let u = dewPointUpper?.value {
                let type: AlertType = .dewPoint(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: ruuviTag.id)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: ruuviTag.id)
                    } else {
                        observer.alertService.unregister(type: type, for: ruuviTag.id)
                    }
                }
            }
        }
        bind(viewModel.dewPointCelsiusLowerBound, fire: false) { observer, lower in
            observer.alertService.setLowerDewPoint(celsius: lower, for: ruuviTag.id)
        }
        bind(viewModel.dewPointCelsiusUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpperDewPoint(celsius: upper, for: ruuviTag.id)
        }
        bind(viewModel.dewPointAlertDescription, fire: false) { observer, dewPointAlertDescription in
            observer.alertService.setDewPoint(description: dewPointAlertDescription, for: ruuviTag.id)
        }
    }

    private func bindTemperatureAlert(_ ruuviTag: RuuviTagSensor) {
        let temperatureLower = viewModel.celsiusLowerBound
        let temperatureUpper = viewModel.celsiusUpperBound
        bind(viewModel.isTemperatureAlertOn, fire: false) {
            [weak temperatureLower, weak temperatureUpper] observer, isOn in
            if let l = temperatureLower?.value, let u = temperatureUpper?.value {
                let type: AlertType = .temperature(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: ruuviTag.id)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: ruuviTag.id)
                    } else {
                        observer.alertService.unregister(type: type, for: ruuviTag.id)
                    }
                }
            }
        }
        bind(viewModel.celsiusLowerBound, fire: false) { observer, lower in
            observer.alertService.setLower(celsius: lower, for: ruuviTag.id)
        }
        bind(viewModel.celsiusUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpper(celsius: upper, for: ruuviTag.id)
        }
        bind(viewModel.temperatureAlertDescription, fire: false) {observer, temperatureAlertDescription in
            observer.alertService.setTemperature(description: temperatureAlertDescription, for: ruuviTag.id)
        }
    }

    private func bindRelativeHumidityAlert(_ ruuviTag: RuuviTagSensor) {
        let relativeHumidityLower = viewModel.relativeHumidityLowerBound
        let relativeHumidityUpper = viewModel.relativeHumidityUpperBound
        bind(viewModel.isRelativeHumidityAlertOn, fire: false) {
            [weak relativeHumidityLower, weak relativeHumidityUpper] observer, isOn in
            if let l = relativeHumidityLower?.value, let u = relativeHumidityUpper?.value {
                let type: AlertType = .relativeHumidity(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: ruuviTag.id)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: ruuviTag.id)
                    } else {
                        observer.alertService.unregister(type: type, for: ruuviTag.id)
                    }
                }
            }
        }
        bind(viewModel.relativeHumidityLowerBound, fire: false) { observer, lower in
            observer.alertService.setLower(relativeHumidity: lower, for: ruuviTag.id)
        }
        bind(viewModel.relativeHumidityUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpper(relativeHumidity: upper, for: ruuviTag.id)
        }
        bind(viewModel.relativeHumidityAlertDescription, fire: false) { observer, relativeHumidityAlertDescription in
            observer.alertService.setRelativeHumidity(description: relativeHumidityAlertDescription, for: ruuviTag.id)
        }
    }

    private func bindPressureAlert(_ ruuviTag: RuuviTagSensor) {
        let pressureLower = viewModel.pressureLowerBound
        let pressureUpper = viewModel.pressureUpperBound
        bind(viewModel.isPressureAlertOn, fire: false) {
            [weak pressureLower, weak pressureUpper] observer, isOn in
            if let l = pressureLower?.value, let u = pressureUpper?.value {
                let type: AlertType = .pressure(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: ruuviTag.id)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: ruuviTag.id)
                    } else {
                        observer.alertService.unregister(type: type, for: ruuviTag.id)
                    }
                }
            }
        }

        bind(viewModel.pressureLowerBound, fire: false) { observer, lower in
            observer.alertService.setLower(pressure: lower, for: ruuviTag.id)
        }

        bind(viewModel.pressureUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpper(pressure: upper, for: ruuviTag.id)
        }

        bind(viewModel.pressureAlertDescription, fire: false) { observer, pressureAlertDescription in
            observer.alertService.setPressure(description: pressureAlertDescription, for: ruuviTag.id)
        }
    }

    private func bindConnectionAlert(_ ruuviTag: RuuviTagSensor) {
        bind(viewModel.isConnectionAlertOn, fire: false) { observer, isOn in
            let type: AlertType = .connection
            let currentState = observer.alertService.isOn(type: type, for: ruuviTag.id)
            if currentState != isOn.bound {
                if isOn.bound {
                    observer.alertService.register(type: type, for: ruuviTag.id)
                } else {
                    observer.alertService.unregister(type: type, for: ruuviTag.id)
                }
            }
        }

        bind(viewModel.connectionAlertDescription, fire: false) { observer, connectionAlertDescription in
            observer.alertService.setConnection(description: connectionAlertDescription, for: ruuviTag.id)
        }
    }

    private func bindMovementAlert(_ ruuviTag: RuuviTagSensor) {
//        bind(viewModel.isMovementAlertOn, fire: false) { observer, isOn in TODO
//            let last = ruuviTag.data.sorted(byKeyPath: "date").last?.movementCounter.value ?? 0
//            let type: AlertType = .movement(last: last)
//            let currentState = observer.alertService.isOn(type: type, for: ruuviTag.id)
//            if currentState != isOn.bound {
//                if isOn.bound {
//                    observer.alertService.register(type: type, for: ruuviTag.id)
//                } else {
//                    observer.alertService.unregister(type: type, for: ruuviTag.id)
//                }
//            }
//        }
//
//        bind(viewModel.movementAlertDescription, fire: false) { observer, movementAlertDescription in
//            observer.alertService.setMovement(description: movementAlertDescription, for: ruuviTag.id)
//        }
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
                uuid == self?.ruuviTag.luid {
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
                uuid == self?.ruuviTag.luid {
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
