// swiftlint:disable file_length
import Foundation
import BTKit
import UIKit
import Future
import RuuviOntology
import RuuviStorage
import RuuviReactor
import RuuviLocal
import RuuviService

class TagSettingsPresenter: NSObject, TagSettingsModuleInput {
    weak var view: TagSettingsViewInput!
    weak var output: TagSettingsModuleOutput!
    var router: TagSettingsRouterInput!
    var errorPresenter: ErrorPresenter!
    var photoPickerPresenter: PhotoPickerPresenter! {
        didSet {
            photoPickerPresenter.delegate = self
        }
    }
    var foreground: BTForeground!
    var background: BTBackground!
    var calibrationService: CalibrationService!
    var alertService: RuuviServiceAlert!
    var settings: RuuviLocalSettings!
    var ruuviLocalImages: RuuviLocalImages!
    var connectionPersistence: RuuviLocalConnections!
    var pushNotificationsManager: PushNotificationsManager!
    var permissionPresenter: PermissionPresenter!
    var ruuviStorage: RuuviStorage!
    var ruuviReactor: RuuviReactor!
    var keychainService: KeychainService!
    var activityPresenter: ActivityPresenter!
    var ruuviOwnershipService: RuuviServiceOwnership!
    var ruuviSensorPropertiesService: RuuviServiceSensorProperties!

    private var ruuviTag: RuuviTagSensor! {
        didSet {
            syncViewModel()
        }
    }
    private var sensorSettings: SensorSettings? {
        didSet {
            syncOffsetCorrection()
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
    private var ruuviTagToken: RuuviReactorToken?
    private var ruuviTagSensorRecordToken: RuuviReactorToken?
    private var advertisementToken: ObservationToken?
    private var heartbeatToken: ObservationToken?
    private var temperatureUnitToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
    private var pressureUnitToken: NSObjectProtocol?
    private var connectToken: NSObjectProtocol?
    private var disconnectToken: NSObjectProtocol?
    private var appDidBecomeActiveToken: NSObjectProtocol?
    private var alertDidChangeToken: NSObjectProtocol?
    private var backgroundUploadProgressToken: NSObjectProtocol?
    private var backgroundToken: NSObjectProtocol?
    private var mutedTillTimer: Timer?

    deinit {
        mutedTillTimer?.invalidate()
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
        backgroundUploadProgressToken?.invalidate()
        backgroundToken?.invalidate()
    }

    func configure(ruuviTag: RuuviTagSensor,
                   temperature: Temperature?,
                   humidity: Humidity?,
                   sensor: SensorSettings?,
                   output: TagSettingsModuleOutput) {
        self.viewModel = TagSettingsViewModel()
        self.output = output
        self.temperature = temperature
        self.humidity = humidity
        self.ruuviTag = ruuviTag

        if let sensorSettings = sensor {
            self.sensorSettings = sensorSettings
        } else {
            self.sensorSettings = SensorSettingsStruct(
                luid: ruuviTag.luid,
                macId: ruuviTag.macId,
                temperatureOffset: nil,
                temperatureOffsetDate: nil,
                humidityOffset: nil,
                humidityOffsetDate: nil,
                pressureOffset: nil,
                pressureOffsetDate: nil
            )
        }

        bindViewModel(to: ruuviTag)
        startObservingRuuviTag()
        startScanningRuuviTag()
        startObservingRuuviTagSensor(ruuviTag: ruuviTag)
        startObservingSettingsChanges()
        startObservingConnectionStatus()
        startObservingApplicationState()
        startObservingAlertChanges()
        startMutedTillTimer()
    }

    func dismiss(completion: (() -> Void)?) {
        router.dismiss(completion: completion)
    }
}

// MARK: - TagSettingsViewOutput
extension TagSettingsPresenter: TagSettingsViewOutput {
    func viewDidLoad() {
        startSubscribeToBackgroundUploadProgressChanges()
    }

    func viewWillAppear() {
        checkPushNotificationsStatus()
        checkLastSensorSettings()
    }

    func viewDidAskToDismiss() {
        router.dismiss()
    }

    func viewDidAskToRandomizeBackground() {
        ruuviSensorPropertiesService.setNextDefaultBackground(for: ruuviTag)
            .on(success: { [weak self] image in
                self?.viewModel.background.value = image
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
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
        ruuviOwnershipService.remove(sensor: ruuviTag).on(success: { [weak self] _ in
            guard let sSelf = self else { return }
            sSelf.output.tagSettingsDidDeleteTag(module: sSelf, ruuviTag: sSelf.ruuviTag)
        }, failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        })
    }

    func viewDidChangeTag(name: String) {
        let finalName = name.isEmpty ? (ruuviTag.macId?.value ?? ruuviTag.id) : name
        ruuviSensorPropertiesService.set(name: finalName, for: ruuviTag)
            .on(failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
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

    func viewDidTapClaimButton() {
        if viewModel.isClaimedTag.value == true {
            ruuviOwnershipService
                .unclaim(sensor: ruuviTag)
                .on(success: { [weak self] unclaimedSensor in
                    self?.ruuviTag = unclaimedSensor
                }, failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
        } else {
            ruuviOwnershipService
                .claim(sensor: ruuviTag)
                .on(success: { [weak self] claimedSensor in
                    self?.ruuviTag = claimedSensor
                }, failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
        }
    }

    func viewDidTapShareButton() {
        router.openShare(for: ruuviTag)
    }

    func viewDidTapTemperatureOffsetCorrection() {
        router.openOffsetCorrection(type: .temperature, ruuviTag: ruuviTag, sensorSettings: sensorSettings)
    }

    func viewDidTapHumidityOffsetCorrection() {
        router.openOffsetCorrection(type: .humidity, ruuviTag: ruuviTag, sensorSettings: sensorSettings)
    }

    func viewDidTapOnPressureOffsetCorrection() {
        router.openOffsetCorrection(type: .pressure, ruuviTag: ruuviTag, sensorSettings: sensorSettings)
    }

    func viewDidTapOnBackgroundIndicator() {
        viewModel.isUploadingBackground.value = false
        viewModel.uploadingBackgroundPercentage.value = nil
        if let macId = ruuviTag.macId {
            ruuviLocalImages.deleteBackgroundUploadProgress(for: macId)
        }
    }
}

// MARK: - PhotoPickerPresenterDelegate
extension TagSettingsPresenter: PhotoPickerPresenterDelegate {
    func photoPicker(presenter: PhotoPickerPresenter, didPick photo: UIImage) {
        viewModel.isUploadingBackground.value = true
        ruuviSensorPropertiesService.set(
            image: photo,
            for: ruuviTag
        ).on(success: { [weak self] _ in
            self?.viewModel.isUploadingBackground.value = false
            self?.viewModel.background.value = photo
        }, failure: { [weak self] error in
            self?.viewModel.isUploadingBackground.value = false
            self?.errorPresenter.present(error: error)
        })
    }
}

// MARK: - Private
extension TagSettingsPresenter {
    private func startMutedTillTimer() {
        self.mutedTillTimer = Timer
            .scheduledTimer(
                withTimeInterval: 5,
                repeats: true
            ) { [weak self] timer in
                guard let sSelf = self else { timer.invalidate(); return }
                sSelf.reloadMutedTill()
            }
    }

    // swiftlint:disable function_body_length
    private func syncViewModel() {
        viewModel.temperatureUnit.value = settings.temperatureUnit
        viewModel.humidityUnit.value = settings.humidityUnit
        viewModel.pressureUnit.value = settings.pressureUnit
        ruuviSensorPropertiesService.getImage(for: ruuviTag)
            .on(success: { [weak self] image in
                self?.viewModel.background.value = image
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
        if let mac = ruuviTag.macId,
           let percentage = ruuviLocalImages.backgroundUploadProgress(for: mac) {
            viewModel.isUploadingBackground.value = percentage < 1.0
            viewModel.uploadingBackgroundPercentage.value = percentage
        } else {
            viewModel.isUploadingBackground.value = false
            viewModel.uploadingBackgroundPercentage.value = nil
        }
        if let luid = ruuviTag.luid {
            viewModel.temperatureAlertDescription.value = alertService.temperatureDescription(for: luid.value)
            viewModel.humidityAlertDescription.value = alertService.humidityDescription(for: luid.value)
            viewModel.dewPointAlertDescription.value = alertService.dewPointDescription(for: luid.value)
            viewModel.pressureAlertDescription.value = alertService.pressureDescription(for: luid.value)
            viewModel.connectionAlertDescription.value = alertService.connectionDescription(for: luid.value)
            viewModel.movementAlertDescription.value = alertService.movementDescription(for: luid.value)
        }

        viewModel.isAuthorized.value = keychainService.userIsAuthorized
        viewModel.canShareTag.value = ruuviTag.isOwner && ruuviTag.isClaimed
        viewModel.canClaimTag.value = ruuviTag.isOwner
        viewModel.owner.value = ruuviTag.owner
        viewModel.isClaimedTag.value = ruuviTag.isClaimed

        if (ruuviTag.name == ruuviTag.luid?.value
            || ruuviTag.name == ruuviTag.macId?.value)
            && !ruuviTag.isCloud {
            viewModel.name.value = nil
        } else {
            viewModel.name.value = ruuviTag.name
        }

        viewModel.isConnectable.value = ruuviTag.isConnectable
        viewModel.isNetworkConnected.value = ruuviTag.any.isCloud
        if let luid = ruuviTag.luid {
            viewModel.isConnected.value = background.isConnected(uuid: luid.value)
            viewModel.keepConnection.value = connectionPersistence.keepConnection(to: luid)
        } else {
            viewModel.isConnected.value = false
            viewModel.keepConnection.value = false
        }
        if let macId = ruuviTag.macId?.value {
            viewModel.mac.value = macId
        }
        viewModel.uuid.value = ruuviTag.luid?.value
        viewModel.version.value = ruuviTag.version
        syncAlerts()
    }
    // swiftlint:enable function_body_length

    private func syncOffsetCorrection() {
        // reload offset correction
        viewModel.temperatureOffsetCorrection.value = sensorSettings?.temperatureOffset
        viewModel.humidityOffsetCorrection.value = sensorSettings?.humidityOffset
        viewModel.pressureOffsetCorrection.value = sensorSettings?.pressureOffset
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
        viewModel.temperatureAlertMutedTill.value = alertService.mutedTill(type: temperature, for: uuid)
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
        viewModel.humidityAlertMutedTill.value = alertService.mutedTill(type: humidity, for: uuid)
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
        viewModel.dewPointAlertMutedTill.value = alertService.mutedTill(type: dewPoint, for: uuid)
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
        viewModel.pressureAlertMutedTill.value = alertService.mutedTill(type: pressure, for: uuid)
    }

    private func sync(connection: AlertType, uuid: String) {
        if case .connection = alertService.alert(for: uuid, of: connection) {
            viewModel.isConnectionAlertOn.value = true
        } else {
            viewModel.isConnectionAlertOn.value = false
        }
        viewModel.connectionAlertMutedTill.value = alertService.mutedTill(type: connection, for: uuid)
    }

    private func sync(movement: AlertType, uuid: String) {
        if case .movement = alertService.alert(for: uuid, of: movement) {
            viewModel.isMovementAlertOn.value = true
        } else {
            viewModel.isMovementAlertOn.value = false
        }
        viewModel.movementAlertMutedTill.value = alertService.mutedTill(type: movement, for: uuid)
    }

    private func startSubscribeToBackgroundUploadProgressChanges() {
        backgroundUploadProgressToken = NotificationCenter
            .default
            .addObserver(forName: .BackgroundPersistenceDidUpdateBackgroundUploadProgress,
                         object: nil,
                         queue: .main) { [weak self] notification in
                guard let sSelf = self else { return }
                if let userInfo = notification.userInfo {
                    let luid = userInfo[BPDidUpdateBackgroundUploadProgressKey.luid] as? LocalIdentifier
                    let macId = userInfo[BPDidUpdateBackgroundUploadProgressKey.macId] as? MACIdentifier
                    if sSelf.ruuviTag.luid?.value == luid?.value
                        || sSelf.ruuviTag.macId?.value == macId?.value {
                        if let percentage = userInfo[BPDidUpdateBackgroundUploadProgressKey.progress] as? Double {
                            sSelf.viewModel.uploadingBackgroundPercentage.value = percentage
                            sSelf.viewModel.isUploadingBackground.value = percentage < 1.0
                        } else {
                            sSelf.viewModel.uploadingBackgroundPercentage.value = nil
                            sSelf.viewModel.isUploadingBackground.value = false
                        }
                    }
                }
            }
        backgroundToken = NotificationCenter
            .default
            .addObserver(forName: .BackgroundPersistenceDidChangeBackground,
                         object: nil,
                         queue: .main) { [weak self] notification in

                guard let sSelf = self else { return }
                if let userInfo = notification.userInfo {
                    let luid = userInfo[BPDidChangeBackgroundKey.luid] as? LocalIdentifier
                    let macId = userInfo[BPDidChangeBackgroundKey.macId] as? MACIdentifier
                    if sSelf.ruuviTag.luid?.value == luid?.value
                        || sSelf.ruuviTag.macId?.value == macId?.value {
                        sSelf.ruuviSensorPropertiesService.getImage(for: sSelf.ruuviTag)
                            .on(success: { [weak sSelf] image in
                                sSelf?.viewModel.background.value = image
                            }, failure: { [weak sSelf] error in
                                sSelf?.errorPresenter.present(error: error)
                            })
                    }
                }
            }
    }

    private func startObservingRuuviTag() {
        ruuviTagToken?.invalidate()
        ruuviTagToken = ruuviReactor.observe { [weak self] (change) in
            switch change {
            case .update(let sensor):
                if sensor.id == self?.ruuviTag.id {
                    self?.ruuviTag = sensor
                }
            case .error(let error):
                self?.errorPresenter.present(error: error)
            default:
                return
            }
        }
    }

    private func startObservingRuuviTagSensor(ruuviTag: RuuviTagSensor) {
        ruuviTagSensorRecordToken?.invalidate()
        ruuviTagSensorRecordToken = ruuviReactor.observeLast(ruuviTag, { [weak self] (changes) in
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
                self?.sync(device: tag, source: .advertisement)
            }
        })
        heartbeatToken?.invalidate()
        heartbeatToken = background.observe(self, uuid: luid.value, closure: { [weak self] (_, device) in
            if let tag = device.ruuvi?.tag {
                self?.sync(device: tag, source: .heartbeat)
            }
        })
    }

    private func sync(device: RuuviTag, source: RuuviTagSensorRecordSource) {
        humidity = device.humidity?.withSensorSettings(sensorSettings: sensorSettings)
        let record = RuuviTagSensorRecordStruct(
            luid: device.luid,
            date: device.date,
            source: source,
            macId: device.mac?.mac,
            rssi: device.rssi,
            temperature: device.temperature,
            humidity: device.humidity,
            pressure: device.pressure,
            acceleration: device.acceleration,
            voltage: device.voltage,
            movementCounter: device.movementCounter,
            measurementSequenceNumber: device.measurementSequenceNumber,
            txPower: device.txPower,
            temperatureOffset: sensorSettings?.temperatureOffset ?? 0.0,
            humidityOffset: sensorSettings?.humidityOffset ?? 0.0,
            pressureOffset: sensorSettings?.pressureOffset ?? 0.0
        ).with(sensorSettings: sensorSettings)
        if viewModel.version.value != device.version {
            viewModel.version.value = device.version
        }
        if !device.isConnected, viewModel.isConnectable.value != device.isConnectable, device.isConnectable {
            viewModel.isConnectable.value = device.isConnectable
        }
        if viewModel.isConnected.value != device.isConnected {
            viewModel.isConnected.value = device.isConnected
        }
        if let mac = device.mac {
            viewModel.mac.value = mac
        }
        if let rssi = device.rssi {
            viewModel.rssi.value = rssi
        }
        viewModel.updateRecord(record)
        reloadMutedTill()
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
            viewModel.isNetworkConnected.value = ruuviTag.isCloud
        }

        bindOffsetCorrection()
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
                    observer.alertService.unmute(type: type, for: uuid)
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
                    observer.alertService.unmute(type: type, for: uuid)
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
                    observer.alertService.unmute(type: type, for: uuid)
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
                    observer.alertService.unmute(type: type, for: uuid)
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
                observer.alertService.unmute(type: type, for: uuid)
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
            observer.ruuviStorage.readLast(strongSelf.ruuviTag).on(success: { record in
                let last = record?.movementCounter ?? 0
                let type: AlertType = .movement(last: last)
                let currentState = observer.alertService.isOn(type: type, for: uuid)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: uuid)
                    } else {
                        observer.alertService.unregister(type: type, for: uuid)
                    }
                    observer.alertService.unmute(type: type, for: uuid)
                }
            }, failure: { error in
                observer.errorPresenter.present(error: error)
            })
        }
        bind(viewModel.movementAlertDescription, fire: false) { observer, movementAlertDescription in
            observer.alertService.setMovement(description: movementAlertDescription, for: uuid)
        }
    }

    private func bindOffsetCorrection() {
        viewModel.temperatureOffsetCorrection.value = sensorSettings?.temperatureOffset
        viewModel.humidityOffsetCorrection.value = sensorSettings?.humidityOffset
        viewModel.pressureOffsetCorrection.value = sensorSettings?.pressureOffset
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

    private func checkLastSensorSettings() {
        ruuviStorage.readSensorSettings(self.ruuviTag).on { settings in
            self.sensorSettings = settings
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
                                self?.updateMutedTill(of: type, for: uuid)
                            }
                         })
    }

    private func reloadMutedTill() {
        if let mutedTill = viewModel.temperatureAlertMutedTill.value,
           mutedTill < Date() {
            viewModel.temperatureAlertMutedTill.value = nil
        }

        if let mutedTill = viewModel.humidityAlertMutedTill.value,
           mutedTill < Date() {
            viewModel.humidityAlertMutedTill.value = nil
        }

        if let mutedTill = viewModel.dewPointAlertMutedTill.value,
           mutedTill < Date() {
            viewModel.dewPointAlertMutedTill.value = nil
        }

        if let mutedTill = viewModel.pressureAlertMutedTill.value,
           mutedTill < Date() {
            viewModel.pressureAlertMutedTill.value = nil
        }

        if let mutedTill = viewModel.connectionAlertMutedTill.value,
           mutedTill < Date() {
            viewModel.connectionAlertMutedTill.value = nil
        }

        if let mutedTill = viewModel.movementAlertMutedTill.value,
           mutedTill < Date() {
            viewModel.movementAlertMutedTill.value = nil
        }
    }

    private func updateMutedTill(of type: AlertType, for uuid: String) {
        var observable: Observable<Date?>
        switch type {
        case .temperature:
            observable = viewModel.temperatureAlertMutedTill
        case .humidity:
            observable = viewModel.humidityAlertMutedTill
        case .dewPoint:
            observable = viewModel.dewPointAlertMutedTill
        case .pressure:
            observable = viewModel.pressureAlertMutedTill
        case .connection:
            observable = viewModel.connectionAlertMutedTill
        case .movement:
            observable = viewModel.movementAlertMutedTill
        }

        let date = alertService.mutedTill(type: type, for: uuid)
        if date != observable.value {
            observable.value = date
        }
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
