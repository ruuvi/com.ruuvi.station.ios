// swiftlint:disable file_length
import UIKit
import CoreLocation
import Humidity
import RuuviOntology
import RuuviLocal
import RuuviService
import RuuviVirtual
import RuuviCore
import RuuviPresenters

class WebTagSettingsPresenter: NSObject, WebTagSettingsModuleInput {
    weak var view: WebTagSettingsViewInput!
    var virtualReactor: VirtualReactor!
    var router: WebTagSettingsRouterInput!
    var errorPresenter: ErrorPresenter!
    var webTagService: VirtualService!
    var settings: RuuviLocalSettings!
    var alertService: RuuviServiceAlert!
    var pushNotificationsManager: RuuviCorePN!
    var permissionsManager: RuuviCorePermission!
    var permissionPresenter: PermissionPresenter!
    var ruuviSensorPropertiesService: RuuviServiceSensorProperties!

    private var temperature: Temperature? {
        didSet {
            view.viewModel.temperature.value = temperature
        }
    }
    private var mutedTillTimer: Timer?
    private var virtualReactorToken: VirtualReactorToken?
    private var temperatureUnitToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
    private var pressureUnitToken: NSObjectProtocol?
    private var appDidBecomeActiveToken: NSObjectProtocol?
    private var alertDidChangeToken: NSObjectProtocol?
    private var virtualSensor: VirtualTagSensor! {
        didSet {
            syncViewModel()
            bindViewModel(to: virtualSensor)
        }
    }

    deinit {
        mutedTillTimer?.invalidate()
        virtualReactorToken?.invalidate()
        temperatureUnitToken?.invalidate()
        appDidBecomeActiveToken?.invalidate()
        humidityUnitToken?.invalidate()
        pressureUnitToken?.invalidate()
        alertDidChangeToken?.invalidate()
    }

    func configure(
        sensor: VirtualTagSensor,
        temperature: Temperature?
    ) {
        self.virtualSensor = sensor
        self.temperature = temperature
        startObservingWebTag()
        startObservingSettingsChanges()
        startObservingApplicationState()
        startObservingAlertChanges()
        startMutedTillTimer()
    }
}

// MARK: - WebTagSettingsViewOutput
extension WebTagSettingsPresenter: WebTagSettingsViewOutput {
    func viewWillAppear() {
        checkPushNotificationsStatus()
        syncViewModel()
    }

    func viewDidAskToDismiss() {
        router.dismiss()
    }

    func viewDidTriggerChangeBackground() {
        router.openBackgroundSelectionView(virtualSensor: virtualSensor)
    }

    func viewDidChangeTag(name: String) {
        let defaultName = virtualSensor.loc == nil
            ? VirtualLocation.current.title
            : VirtualLocation.manual.title
        let finalName = name.isEmpty ? defaultName : name
        let operation = webTagService.update(name: finalName, of: virtualSensor)
        operation.on(failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }

    func viewDidAskToRemoveWebTag() {
        view.showTagRemovalConfirmationDialog()
    }

    func viewDidConfirmTagRemoval() {
        let operation = webTagService.remove(sensor: virtualSensor)
        operation.on(success: { [weak self] _ in
            self?.router.dismiss()
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }

    func viewDidAskToSelectLocation() {
        router.openLocationPicker(output: self)
    }

    func viewDidAskToClearLocation() {
        view.showClearLocationConfirmationDialog()
    }

    func viewDidConfirmToClearLocation() {
        let operation = webTagService.clearLocation(
            of: virtualSensor,
            name: VirtualLocation.current.title
        )
        operation.on(failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }

    func viewDidTapOnAlertsDisabledView() {
        let isPN = view.viewModel.isPushNotificationsEnabled.value ?? false
        let isFixed = view.viewModel.location.value != nil
        let isLA = view.viewModel.isLocationAuthorizedAlways.value ?? false

        if isFixed {
            if !isPN {
                permissionPresenter.presentNoPushNotificationsPermission()
            }
        } else {
            if !isPN && !isLA {
                view.showBothNoPNPermissionAndNoLocationPermission()
            } else if !isLA {
                permissionPresenter.presentNoLocationPermission()
            } else if !isPN {
                permissionPresenter.presentNoPushNotificationsPermission()
            }
        }
    }

    func viewDidAskToOpenSettings() {
        router.openSettings()
    }
}

// MARK: - Observations
extension WebTagSettingsPresenter {
    private func startObservingSettingsChanges() {
        temperatureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .TemperatureUnitDidChange,
                         object: nil,
                         queue: .main) { [weak self] _ in
            self?.view.viewModel.temperatureUnit.value = self?.settings.temperatureUnit
        }
        humidityUnitToken = NotificationCenter
            .default
            .addObserver(forName: .HumidityUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
            self?.view.viewModel.humidityUnit.value = self?.settings.humidityUnit
        })
        pressureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .PressureUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
            self?.view.viewModel.pressureUnit.value = self?.settings.pressureUnit
        })
    }
}

// MARK: - LocationPickerModuleOutput
extension WebTagSettingsPresenter: LocationPickerModuleOutput {
    func locationPicker(module: LocationPickerModuleInput, didPick location: Location) {
        let operation = webTagService.update(location: location, of: virtualSensor)
        operation.on(failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        })
        module.dismiss()
    }
}

// MARK: - Private
extension WebTagSettingsPresenter {
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

    private func bindViewModel(to webTag: VirtualTagSensor) {
        bindTemperatureAlert(webTag)
        bindHumidityAlert(webTag)
        bindPressureAlert(webTag)
    }

    private func bindTemperatureAlert(_ sensor: VirtualTagSensor) {
        let temperatureLower = view.viewModel.temperatureLowerBound
        let temperatureUpper = view.viewModel.temperatureUpperBound
        bind(view.viewModel.isTemperatureAlertOn, fire: false) {
            [weak temperatureLower,
             weak temperatureUpper] observer, isOn in
            if let l = temperatureLower?.value?.converted(to: .celsius).value,
               let u = temperatureUpper?.value?.converted(to: .celsius).value {
                let type: AlertType = .temperature(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: sensor)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: sensor)
                    } else {
                        observer.alertService.unregister(type: type, for: sensor)
                    }
                    observer.alertService.unmute(type: type, for: sensor)
                }
            }
        }
        bind(view.viewModel.temperatureLowerBound, fire: false) { observer, lower in
            if let l = lower?.converted(to: .celsius).value {
                observer.alertService.setLower(celsius: l, for: sensor)
            }
        }
        bind(view.viewModel.temperatureUpperBound, fire: false) { observer, upper in
            if let u = upper?.converted(to: .celsius).value {
                observer.alertService.setUpper(celsius: u, for: sensor)
            }
        }
        bind(view.viewModel.temperatureAlertDescription, fire: false) {observer, temperatureAlertDescription in
            observer.alertService.setTemperature(description: temperatureAlertDescription, for: sensor)
        }
    }

    private func bindHumidityAlert(_ sensor: VirtualTagSensor) {
        let humidityLower = view.viewModel.humidityLowerBound
        let humidityUpper = view.viewModel.humidityUpperBound
        bind(view.viewModel.isHumidityAlertOn, fire: false) {
            [weak humidityLower, weak humidityUpper] observer, isOn in
            if let l = humidityLower?.value,
               let u = humidityUpper?.value {
                let type: AlertType = .humidity(lower: l, upper: u)
                let currentState = observer.alertService.isOn(
                    type: type,
                    for: sensor.id
                )
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: sensor)
                    } else {
                        observer.alertService.unregister(type: type, for: sensor)
                    }
                    observer.alertService.unmute(type: type, for: sensor)
                }
            }
        }
        bind(view.viewModel.humidityLowerBound, fire: false) { observer, lower in
            observer.alertService.setLower(humidity: lower, for: sensor)
        }
        bind(view.viewModel.humidityUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpper(humidity: upper, for: sensor)
        }
        bind(view.viewModel.humidityAlertDescription, fire: false) {
            observer, humidityAlertDescription in
            observer.alertService.setHumidity(description: humidityAlertDescription, for: sensor)
        }
    }

    private func bindPressureAlert(_ webTag: VirtualTagSensor) {
        let pressureLower = view.viewModel.pressureLowerBound
        let pressureUpper = view.viewModel.pressureUpperBound
        bind(view.viewModel.isPressureAlertOn, fire: false) {
            [weak pressureLower, weak pressureUpper] observer, isOn in
            if let l = pressureLower?.value?.converted(to: .hectopascals).value,
               let u = pressureUpper?.value?.converted(to: .hectopascals).value {
                let type: AlertType = .pressure(lower: l, upper: u)
                let currentState = observer.alertService.isOn(
                    type: type,
                    for: webTag.id
                )
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: webTag)
                    } else {
                        observer.alertService.unregister(type: type, for: webTag)
                    }
                    observer.alertService.unmute(type: type, for: webTag)
                }
            }
        }

        bind(view.viewModel.pressureLowerBound, fire: false) { observer, lower in
            if let l = lower?.converted(to: .hectopascals).value {
                observer.alertService.setLower(pressure: l, for: webTag)
            }
        }

        bind(view.viewModel.pressureUpperBound, fire: false) { observer, upper in
            if let u = upper?.converted(to: .hectopascals).value {
                observer.alertService.setUpper(pressure: u, for: webTag)
            }
        }

        bind(view.viewModel.pressureAlertDescription, fire: false) { observer, pressureAlertDescription in
            observer.alertService.setPressure(description: pressureAlertDescription, for: webTag)
        }
    }

    private func startObservingWebTag() {
        virtualReactorToken?.invalidate()
        let id = virtualSensor.id
        virtualReactorToken = virtualReactor.observe { [weak self] change in
            switch change {
            case .delete(let sensor):
                if sensor.id == id {
                    self?.router.dismiss()
                }
            case .update(let sensor):
                if sensor.id == id {
                    self?.virtualSensor = sensor
                    self?.syncViewModel()
                }
            case .error(let error):
                self?.errorPresenter.present(error: error)
            default:
                break
            }
        }
    }

    private func startObservingApplicationState() {
        appDidBecomeActiveToken = NotificationCenter
            .default
            .addObserver(forName: UIApplication.didBecomeActiveNotification,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (_) in
            self?.checkPushNotificationsStatus()
            self?.view.viewModel.isLocationAuthorizedAlways.value
                = self?.permissionsManager.locationAuthorizationStatus == .authorizedAlways
        })
    }

    // swiftlint:disable:next function_body_length
    private func syncViewModel() {
        ruuviSensorPropertiesService.getImage(for: virtualSensor)
            .on(success: { [weak self] image in
                self?.view.viewModel.background.value = image
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
        view.viewModel.isLocationAuthorizedAlways.value
            = permissionsManager.locationAuthorizationStatus == .authorizedAlways
        view.viewModel.temperatureUnit.value = settings.temperatureUnit
        view.viewModel.humidityUnit.value = settings.humidityUnit
        view.viewModel.pressureUnit.value = settings.pressureUnit
        if virtualSensor.name == VirtualLocation.manual.title {
            view.viewModel.name.value = nil
        } else {
            view.viewModel.name.value = virtualSensor.name
        }

        view.viewModel.uuid.value = virtualSensor.id
        view.viewModel.location.value = virtualSensor.loc

        view.isNameChangedEnabled = view.viewModel.location.value != nil

        view.viewModel.temperatureAlertDescription.value
            = alertService.temperatureDescription(for: virtualSensor.id)
        view.viewModel.humidityAlertDescription.value
            = alertService.humidityDescription(for: virtualSensor.id)
        view.viewModel.pressureAlertDescription.value
            = alertService.pressureDescription(for: virtualSensor.id)

        let temperatureAlertType: AlertType = .temperature(lower: 0, upper: 0)
        if case .temperature(let lower, let upper) = alertService.alert(
            for: virtualSensor.id,
            of: temperatureAlertType
        ) {
            view.viewModel.isTemperatureAlertOn.value = true
            view.viewModel.temperatureLowerBound.value = Temperature(lower, unit: .celsius)
            view.viewModel.temperatureUpperBound.value =  Temperature(upper, unit: .celsius)
        } else {
            view.viewModel.isTemperatureAlertOn.value = false
            if let celsiusLower = alertService.lowerCelsius(for: virtualSensor.id) {
                view.viewModel.temperatureLowerBound.value = Temperature(celsiusLower, unit: .celsius)
            }
            if let celsiusUpper = alertService.upperCelsius(for: virtualSensor.id) {
                view.viewModel.temperatureUpperBound.value = Temperature(celsiusUpper, unit: .celsius)
            }
        }
        view.viewModel.temperatureAlertMutedTill.value
            = alertService.mutedTill(type: temperatureAlertType, for: virtualSensor.id)

        let humidityAlertType: AlertType = .humidity(lower: .init(value: 0, unit: .absolute),
                                                     upper: .init(value: 0, unit: .absolute))
        if case .humidity(let lower, let upper)
            = alertService.alert(for: virtualSensor.id, of: humidityAlertType) {
            view.viewModel.isHumidityAlertOn.value = true
            view.viewModel.humidityLowerBound.value = lower
            view.viewModel.humidityUpperBound.value = upper
        } else {
            view.viewModel.isHumidityAlertOn.value = false
            if let humidityLower = alertService.lowerHumidity(for: virtualSensor.id) {
                view.viewModel.humidityLowerBound.value = humidityLower
            }
            if let humidityUpper = alertService.upperHumidity(for: virtualSensor.id) {
                view.viewModel.humidityUpperBound.value = humidityUpper
            }
        }
        view.viewModel.humidityAlertMutedTill.value = alertService.mutedTill(
            type: humidityAlertType,
            for: virtualSensor.id
        )

        let pressureAlertType: AlertType = .pressure(lower: 0, upper: 0)
        if case .pressure(let lower, let upper) = alertService.alert(for: virtualSensor.id, of: pressureAlertType) {
            view.viewModel.isPressureAlertOn.value = true
            view.viewModel.pressureLowerBound.value = Pressure(lower, unit: .hectopascals)
            view.viewModel.pressureUpperBound.value =  Pressure(upper, unit: .hectopascals)
        } else {
            view.viewModel.isPressureAlertOn.value = false
            if let pressureLowerBound = alertService.lowerPressure(for: virtualSensor.id) {
                view.viewModel.pressureLowerBound.value = Pressure(pressureLowerBound, unit: .hectopascals)
            }
            if let pressureUpperBound = alertService.upperPressure(for: virtualSensor.id) {
                view.viewModel.pressureUpperBound.value = Pressure(pressureUpperBound, unit: .hectopascals)
            }
        }
        view.viewModel.pressureAlertMutedTill.value = alertService.mutedTill(
            type: pressureAlertType,
            for: virtualSensor.id
        )

        reloadMutedTill()
    }

    private func checkPushNotificationsStatus() {
        pushNotificationsManager.getRemoteNotificationsAuthorizationStatus { [weak self] (status) in
            switch status {
            case .notDetermined:
                self?.pushNotificationsManager.registerForRemoteNotifications()
            case .authorized:
                self?.view.viewModel.isPushNotificationsEnabled.value = true
            case .denied:
                self?.view.viewModel.isPushNotificationsEnabled.value = false
            }
        }
    }

    private func startObservingAlertChanges() {
        alertDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .RuuviServiceAlertDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
            if let userInfo = notification.userInfo,
                let virtualSensor = userInfo[RuuviServiceAlertDidChangeKey.virtualSensor] as? VirtualSensor,
                virtualSensor.id == self?.view.viewModel.uuid.value,
                let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType {
                self?.updateIsOnState(of: type, for: virtualSensor.id)
                self?.updateMutedTill(of: type, for: virtualSensor.id)
            }
        })
    }

    private func updateIsOnState(of type: AlertType, for uuid: String) {
        var observable: Observable<Bool?>?
        switch type {
        case .temperature:
            observable = view.viewModel.isTemperatureAlertOn
        case .relativeHumidity:
            observable = view.viewModel.isRelativeHumidityAlertOn
        case .humidity:
            observable = view.viewModel.isHumidityAlertOn
        case .pressure:
            observable = view.viewModel.isPressureAlertOn
        case .connection, .movement, .signal:
            observable = nil
        }

        if let observable = observable {
            let isOn = alertService.isOn(type: type, for: uuid)
            if isOn != observable.value {
                observable.value = isOn
            }
        }
    }

    private func reloadMutedTill() {
        if let mutedTill = view.viewModel.temperatureAlertMutedTill.value,
           mutedTill < Date() {
            view.viewModel.temperatureAlertMutedTill.value = nil
        }

        if let mutedTill = view.viewModel.humidityAlertMutedTill.value,
           mutedTill < Date() {
            view.viewModel.humidityAlertMutedTill.value = nil
        }

        if let mutedTill = view.viewModel.pressureAlertMutedTill.value,
           mutedTill < Date() {
            view.viewModel.pressureAlertMutedTill.value = nil
        }

    }

    private func updateMutedTill(of type: AlertType, for uuid: String) {
        var observable: Observable<Date?>?
        switch type {
        case .temperature:
            observable = view.viewModel.temperatureAlertMutedTill
        case .relativeHumidity:
            observable = view.viewModel.relativeHumidityAlertMutedTill
        case .humidity:
            observable = view.viewModel.humidityAlertMutedTill
        case .pressure:
            observable = view.viewModel.pressureAlertMutedTill
        case .connection, .movement, .signal:
            observable = nil
        }

        if let observable = observable {
            let date = alertService.mutedTill(type: type, for: uuid)
            if date != observable.value {
                observable.value = date
            }
        }
    }
}
// swiftlint:enable file_length
