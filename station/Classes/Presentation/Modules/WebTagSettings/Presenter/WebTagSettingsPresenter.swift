// swiftlint:disable file_length
import UIKit
import RealmSwift
import CoreLocation
import Humidity

class WebTagSettingsPresenter: NSObject, WebTagSettingsModuleInput {
    weak var view: WebTagSettingsViewInput!
    var router: WebTagSettingsRouterInput!
    var backgroundPersistence: BackgroundPersistence!
    var errorPresenter: ErrorPresenter!
    var webTagService: WebTagService!
    var settings: Settings!
    var alertService: AlertService!
    var pushNotificationsManager: PushNotificationsManager!
    var permissionsManager: PermissionsManager!
    var permissionPresenter: PermissionPresenter!
    var photoPickerPresenter: PhotoPickerPresenter! {
        didSet {
            photoPickerPresenter.delegate = self
        }
    }
    private var temperature: Temperature? {
        didSet {
            view.viewModel.temperature.value = temperature
        }
    }
    private var webTagToken: NotificationToken?
    private var temperatureUnitToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
    private var pressureUnitToken: NSObjectProtocol?
    private var appDidBecomeActiveToken: NSObjectProtocol?
    private var alertDidChangeToken: NSObjectProtocol?
    private var webTag: WebTagRealm! {
        didSet {
            syncViewModel()
            bindViewModel(to: webTag)
        }
    }

    deinit {
        webTagToken?.invalidate()
        temperatureUnitToken?.invalidate()
        appDidBecomeActiveToken?.invalidate()
        humidityUnitToken?.invalidate()
        pressureUnitToken?.invalidate()
        alertDidChangeToken?.invalidate()
    }

    func configure(webTag: WebTagRealm,
                   temperature: Temperature?) {
        self.webTag = webTag
        self.temperature = temperature
        startObservingWebTag()
        startObservingSettingsChanges()
        startObservingApplicationState()
        startObservingAlertChanges()
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

    func viewDidAskToRandomizeBackground() {
        view.viewModel.background.value = backgroundPersistence.setNextDefaultBackground(for: webTag.uuid.luid)
    }

    func viewDidAskToSelectBackground(sourceView: UIView) {
        photoPickerPresenter.pick(sourceView: sourceView)
    }

    func viewDidChangeTag(name: String) {
        let defaultName = webTag.location == nil
            ? WebTagLocationSource.current.title
            : WebTagLocationSource.manual.title
        let finalName = name.isEmpty ? defaultName : name
        let operation = webTagService.update(name: finalName, of: webTag)
        operation.on(failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }

    func viewDidAskToRemoveWebTag() {
        view.showTagRemovalConfirmationDialog()
    }

    func viewDidConfirmTagRemoval() {
        let operation = webTagService.remove(webTag: webTag)
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
        let operation = webTagService.clearLocation(of: webTag)
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

// MARK: - PhotoPickerPresenterDelegate
extension WebTagSettingsPresenter: PhotoPickerPresenterDelegate {
    func photoPicker(presenter: PhotoPickerPresenter, didPick photo: UIImage) {
        let set = backgroundPersistence.setCustomBackground(image: photo, for: webTag.uuid.luid)
        set.on(success: { [weak self] _ in
            self?.view.viewModel.background.value = photo
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }
}

// MARK: - LocationPickerModuleOutput
extension WebTagSettingsPresenter: LocationPickerModuleOutput {
    func locationPicker(module: LocationPickerModuleInput, didPick location: Location) {
        let operation = webTagService.update(location: location, of: webTag)
        operation.on(failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        })
        module.dismiss()
    }
}

// MARK: - Private
extension WebTagSettingsPresenter {

    private func bindViewModel(to webTag: WebTagRealm) {
        bindTemperatureAlert(webTag)
        bindHumidityAlert(webTag)
        bindDewPoint(webTag)
        bindPressureAlert(webTag)
    }

    private func bindTemperatureAlert(_ webTag: WebTagRealm) {
        let temperatureLower = view.viewModel.temperatureLowerBound
        let temperatureUpper = view.viewModel.temperatureUpperBound
        bind(view.viewModel.isTemperatureAlertOn, fire: false) {
            [weak temperatureLower,
             weak temperatureUpper] observer, isOn in
            if let l = temperatureLower?.value?.converted(to: .celsius).value,
               let u = temperatureUpper?.value?.converted(to: .celsius).value {
                let type: AlertType = .temperature(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: webTag.uuid)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: webTag.uuid)
                    } else {
                        observer.alertService.unregister(type: type, for: webTag.uuid)
                    }
                }
            }
        }
        bind(view.viewModel.temperatureLowerBound, fire: false) { observer, lower in
            if let l = lower?.converted(to: .celsius).value {
                observer.alertService.setLower(celsius: l, for: webTag.uuid)
            }
        }
        bind(view.viewModel.temperatureUpperBound, fire: false) { observer, upper in
            if let u = upper?.converted(to: .celsius).value {
                observer.alertService.setUpper(celsius: u, for: webTag.uuid)
            }
        }
        bind(view.viewModel.temperatureAlertDescription, fire: false) {observer, temperatureAlertDescription in
            observer.alertService.setTemperature(description: temperatureAlertDescription, for: webTag.uuid)
        }
    }

    private func bindHumidityAlert(_ webTag: WebTagRealm) {
        let humidityLower = view.viewModel.humidityLowerBound
        let humidityUpper = view.viewModel.humidityUpperBound
        bind(view.viewModel.isHumidityAlertOn, fire: false) {
            [weak humidityLower, weak humidityUpper] observer, isOn in
            if let l = humidityLower?.value,
               let u = humidityUpper?.value {
                let type: AlertType = .humidity(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: webTag.uuid)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: webTag.uuid)
                    } else {
                        observer.alertService.unregister(type: type, for: webTag.uuid)
                    }
                }
            }
        }
        bind(view.viewModel.humidityLowerBound, fire: false) { observer, lower in
            observer.alertService.setLower(humidity: lower, for: webTag.uuid)
        }
        bind(view.viewModel.humidityUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpper(humidity: upper, for: webTag.uuid)
        }
        bind(view.viewModel.humidityAlertDescription, fire: false) {
            observer, humidityAlertDescription in
            observer.alertService.setHumidity(description: humidityAlertDescription, for: webTag.uuid)
        }
    }

    private func bindPressureAlert(_ webTag: WebTagRealm) {
        let pressureLower = view.viewModel.pressureLowerBound
        let pressureUpper = view.viewModel.pressureUpperBound
        bind(view.viewModel.isPressureAlertOn, fire: false) {
            [weak pressureLower, weak pressureUpper] observer, isOn in
            if let l = pressureLower?.value?.converted(to: .hectopascals).value,
               let u = pressureUpper?.value?.converted(to: .hectopascals).value {
                let type: AlertType = .pressure(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: webTag.uuid)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: webTag.uuid)
                    } else {
                        observer.alertService.unregister(type: type, for: webTag.uuid)
                    }
                }
            }
        }

        bind(view.viewModel.pressureLowerBound, fire: false) { observer, lower in
            if let l = lower?.converted(to: .hectopascals).value {
                observer.alertService.setLower(pressure: l, for: webTag.uuid)
            }
        }

        bind(view.viewModel.pressureUpperBound, fire: false) { observer, upper in
            if let u = upper?.converted(to: .hectopascals).value {
                observer.alertService.setUpper(pressure: u, for: webTag.uuid)
            }
        }

        bind(view.viewModel.pressureAlertDescription, fire: false) { observer, pressureAlertDescription in
            observer.alertService.setPressure(description: pressureAlertDescription, for: webTag.uuid)
        }
    }

    private func bindDewPoint(_ webTag: WebTagRealm) {
        let dewPointLower = view.viewModel.dewPointLowerBound
        let dewPointUpper = view.viewModel.dewPointUpperBound
        bind(view.viewModel.isDewPointAlertOn, fire: false) {
            [weak dewPointLower, weak dewPointUpper] observer, isOn in
            if let l = dewPointLower?.value?.converted(to: .celsius).value,
               let u = dewPointUpper?.value?.converted(to: .celsius).value {
                let type: AlertType = .dewPoint(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: webTag.uuid)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, for: webTag.uuid)
                    } else {
                        observer.alertService.unregister(type: type, for: webTag.uuid)
                    }
                }
            }
        }
        bind(view.viewModel.dewPointLowerBound, fire: false) { observer, lower in
            if let l = lower?.converted(to: .celsius).value {
                observer.alertService.setLowerDewPoint(celsius: l, for: webTag.uuid)
            }
        }
        bind(view.viewModel.dewPointUpperBound, fire: false) { observer, upper in
            if let u = upper?.converted(to: .celsius).value {
                observer.alertService.setUpperDewPoint(celsius: u, for: webTag.uuid)
            }
        }
        bind(view.viewModel.dewPointAlertDescription, fire: false) { observer, dewPointAlertDescription in
            observer.alertService.setDewPoint(description: dewPointAlertDescription, for: webTag.uuid)
        }
    }

    private func startObservingWebTag() {
        webTagToken = webTag.observe({ [weak self] (change) in
            switch change {
            case .change:
                self?.syncViewModel()
            case .deleted:
                self?.router.dismiss()
            case .error(let error):
                self?.errorPresenter.present(error: error)
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
            self?.view.viewModel.isLocationAuthorizedAlways.value
                = self?.permissionsManager.locationAuthorizationStatus == .authorizedAlways
        })
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func syncViewModel() {
        view.viewModel.isLocationAuthorizedAlways.value
            = permissionsManager.locationAuthorizationStatus == .authorizedAlways
        view.viewModel.currentTemperature.value = webTag.data.last?.record?.temperature
        view.viewModel.temperatureUnit.value = settings.temperatureUnit
        view.viewModel.humidityUnit.value = settings.humidityUnit
        view.viewModel.pressureUnit.value = settings.pressureUnit
        view.viewModel.background.value = backgroundPersistence.background(for: webTag.uuid.luid)
        if webTag.name == WebTagLocationSource.manual.title {
            view.viewModel.name.value = nil
        } else {
            view.viewModel.name.value = webTag.name
        }

        view.viewModel.uuid.value = webTag.uuid
        if let webTagLocation = webTag.location {
            view.viewModel.location.value = webTagLocation.location
        } else {
            view.viewModel.location.value = nil
        }

        view.isNameChangedEnabled = view.viewModel.location.value != nil

        view.viewModel.temperatureAlertDescription.value
            = alertService.temperatureDescription(for: webTag.uuid)
        view.viewModel.humidityAlertDescription.value
            = alertService.humidityDescription(for: webTag.uuid)
        view.viewModel.pressureAlertDescription.value
            = alertService.pressureDescription(for: webTag.uuid)

        let temperatureAlertType: AlertType = .temperature(lower: 0, upper: 0)
        if case .temperature(let lower, let upper) = alertService.alert(for: webTag.uuid, of: temperatureAlertType) {
            view.viewModel.isTemperatureAlertOn.value = true
            view.viewModel.temperatureLowerBound.value = Temperature(lower, unit: .celsius)
            view.viewModel.temperatureUpperBound.value =  Temperature(upper, unit: .celsius)
        } else {
            view.viewModel.isTemperatureAlertOn.value = false
            if let celsiusLower = alertService.lowerCelsius(for: webTag.uuid) {
                view.viewModel.temperatureLowerBound.value = Temperature(celsiusLower, unit: .celsius)
            }
            if let celsiusUpper = alertService.upperCelsius(for: webTag.uuid) {
                view.viewModel.temperatureUpperBound.value = Temperature(celsiusUpper, unit: .celsius)
            }
        }

        let humidityAlertType: AlertType = .humidity(lower: .init(value: 0, unit: .absolute),
                                                     upper: .init(value: 0, unit: .absolute))
        if case .humidity(let lower, let upper)
            = alertService.alert(for: webTag.uuid, of: humidityAlertType) {
            view.viewModel.isHumidityAlertOn.value = true
            view.viewModel.humidityLowerBound.value = lower
            view.viewModel.humidityUpperBound.value = upper
        } else {
            view.viewModel.isHumidityAlertOn.value = false
            if let humidityLower = alertService.lowerHumidity(for: webTag.uuid) {
                view.viewModel.humidityLowerBound.value = humidityLower
            }
            if let humidityUpper = alertService.upperHumidity(for: webTag.uuid) {
                view.viewModel.humidityUpperBound.value = humidityUpper
            }
        }

        let dewPointAlertType: AlertType = .dewPoint(lower: 0, upper: 0)
        if case .dewPoint(let lower, let upper) = alertService.alert(for: webTag.uuid, of: dewPointAlertType) {
            view.viewModel.isDewPointAlertOn.value = true
            view.viewModel.dewPointLowerBound.value = Temperature(value: lower, unit: .celsius)
            view.viewModel.dewPointUpperBound.value = Temperature(value: upper, unit: .celsius)
        } else {
            view.viewModel.isDewPointAlertOn.value = false
            if let lowerBound = alertService.lowerDewPointCelsius(for: webTag.uuid) {
                view.viewModel.dewPointLowerBound.value = Temperature(value: lowerBound, unit: .celsius)
            }
            if let upperBound = alertService.upperDewPointCelsius(for: webTag.uuid) {
                view.viewModel.dewPointUpperBound.value = Temperature(value: upperBound, unit: .celsius)
            }
        }

        let pressureAlertType: AlertType = .pressure(lower: 0, upper: 0)
        if case .pressure(let lower, let upper) = alertService.alert(for: webTag.uuid, of: pressureAlertType) {
            view.viewModel.isPressureAlertOn.value = true
            view.viewModel.pressureLowerBound.value = Pressure(lower, unit: .hectopascals)
            view.viewModel.pressureUpperBound.value =  Pressure(upper, unit: .hectopascals)
        } else {
            view.viewModel.isPressureAlertOn.value = false
            if let pressureLowerBound = alertService.lowerPressure(for: webTag.uuid) {
                view.viewModel.pressureLowerBound.value = Pressure(pressureLowerBound, unit: .hectopascals)
            }
            if let pressureUpperBound = alertService.upperPressure(for: webTag.uuid) {
                view.viewModel.pressureUpperBound.value = Pressure(pressureUpperBound, unit: .hectopascals)
            }
        }
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
            .addObserver(forName: .AlertServiceAlertDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
            if let userInfo = notification.userInfo,
                let uuid = userInfo[AlertServiceAlertDidChangeKey.uuid] as? String,
                uuid == self?.view.viewModel.uuid.value,
                let type = userInfo[AlertServiceAlertDidChangeKey.type] as? AlertType {
                self?.updateIsOnState(of: type, for: uuid)
            }
        })
    }

    private func updateIsOnState(of type: AlertType, for uuid: String) {
        var observable: Observable<Bool?>?
        switch type {
        case .temperature:
            observable = view.viewModel.isTemperatureAlertOn
        case .humidity:
            observable = view.viewModel.isHumidityAlertOn
        case .dewPoint:
            observable = view.viewModel.isDewPointAlertOn
        case .pressure:
            observable = view.viewModel.isPressureAlertOn
        case .connection:
            observable = nil
        case .movement:
            observable = nil
        }

        if let observable = observable {
            let isOn = alertService.isOn(type: type, for: uuid)
            if isOn != observable.value {
                observable.value = isOn
            }
        }
    }
}
// swiftlint:enable file_length
