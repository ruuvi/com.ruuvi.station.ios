// swiftlint:disable file_length
import UIKit
import RealmSwift
import CoreLocation

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

    private var webTagToken: NotificationToken?
    private var temperatureUnitToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
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
        if let temperatureUnitToken = temperatureUnitToken {
            NotificationCenter.default.removeObserver(temperatureUnitToken)
        }
        if let appDidBecomeActiveToken = appDidBecomeActiveToken {
            NotificationCenter.default.removeObserver(appDidBecomeActiveToken)
        }
        if let humidityUnitToken = humidityUnitToken {
            NotificationCenter.default.removeObserver(humidityUnitToken)
        }
        if let alertDidChangeToken = alertDidChangeToken {
            NotificationCenter.default.removeObserver(alertDidChangeToken)
        }
    }

    func configure(webTag: WebTagRealm) {
        self.webTag = webTag
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
    }

    func viewDidAskToDismiss() {
        router.dismiss()
    }

    func viewDidAskToRandomizeBackground() {
        view.viewModel.background.value = backgroundPersistence.setNextDefaultBackground(for: webTag.uuid)
    }

    func viewDidAskToSelectBackground(sourceView: UIView) {
        photoPickerPresenter.pick(sourceView: sourceView)
    }

    func viewDidChangeTag(name: String) {
        let defaultName = webTag.location == nil ? WebTagLocationSource.current.title : WebTagLocationSource.manual.title
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
    }
}

// MARK: - PhotoPickerPresenterDelegate
extension WebTagSettingsPresenter: PhotoPickerPresenterDelegate {
    func photoPicker(presenter: PhotoPickerPresenter, didPick photo: UIImage) {
        let set = backgroundPersistence.setCustomBackground(image: photo, for: webTag.uuid)
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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func bindViewModel(to webTag: WebTagRealm) {
        // temperature alert
        let temperatureLower = view.viewModel.celsiusLowerBound
        let temperatureUpper = view.viewModel.celsiusUpperBound
        bind(view.viewModel.isTemperatureAlertOn, fire: false) {
            [weak temperatureLower, weak temperatureUpper] observer, isOn in
            if let l = temperatureLower?.value, let u = temperatureUpper?.value {
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
        bind(view.viewModel.celsiusLowerBound, fire: false) { observer, lower in
            observer.alertService.setLower(celsius: lower, for: webTag.uuid)
        }
        bind(view.viewModel.celsiusUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpper(celsius: upper, for: webTag.uuid)
        }
        bind(view.viewModel.temperatureAlertDescription, fire: false) {observer, temperatureAlertDescription in
            observer.alertService.setTemperature(description: temperatureAlertDescription, for: webTag.uuid)
        }

        // relative humidity alert
        let relativeHumidityLower = view.viewModel.relativeHumidityLowerBound
        let relativeHumidityUpper = view.viewModel.relativeHumidityUpperBound
        bind(view.viewModel.isRelativeHumidityAlertOn, fire: false) {
            [weak relativeHumidityLower, weak relativeHumidityUpper] observer, isOn in
            if let l = relativeHumidityLower?.value, let u = relativeHumidityUpper?.value {
                let type: AlertType = .relativeHumidity(lower: l, upper: u)
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
        bind(view.viewModel.relativeHumidityLowerBound, fire: false) { observer, lower in
            observer.alertService.setLower(relativeHumidity: lower, for: webTag.uuid)
        }
        bind(view.viewModel.relativeHumidityUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpper(relativeHumidity: upper, for: webTag.uuid)
        }
        bind(view.viewModel.relativeHumidityAlertDescription, fire: false) {
            observer, relativeHumidityAlertDescription in
            observer.alertService.setRelativeHumidity(description: relativeHumidityAlertDescription, for: webTag.uuid)
        }

        // absolute humidity alert
        let absoluteHumidityLower = view.viewModel.absoluteHumidityLowerBound
        let absoluteHumidityUpper = view.viewModel.absoluteHumidityUpperBound
        bind(view.viewModel.isAbsoluteHumidityAlertOn, fire: false) {
            [weak absoluteHumidityLower, weak absoluteHumidityUpper] observer, isOn in
            if let l = absoluteHumidityLower?.value, let u = absoluteHumidityUpper?.value {
                let type: AlertType = .absoluteHumidity(lower: l, upper: u)
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

        bind(view.viewModel.absoluteHumidityLowerBound, fire: false) { observer, lower in
            observer.alertService.setLower(absoluteHumidity: lower, for: webTag.uuid)
        }

        bind(view.viewModel.absoluteHumidityUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpper(absoluteHumidity: upper, for: webTag.uuid)
        }

        bind(view.viewModel.absoluteHumidityAlertDescription, fire: false) {
            observer, absoluteHumidityAlertDescription in
            observer.alertService.setAbsoluteHumidity(description: absoluteHumidityAlertDescription, for: webTag.uuid)
        }

        // dew point alert
        let dewPointLower = view.viewModel.dewPointCelsiusLowerBound
        let dewPointUpper = view.viewModel.dewPointCelsiusUpperBound
        bind(view.viewModel.isDewPointAlertOn, fire: false) {
            [weak dewPointLower, weak dewPointUpper] observer, isOn in
            if let l = dewPointLower?.value, let u = dewPointUpper?.value {
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
        bind(view.viewModel.dewPointCelsiusLowerBound, fire: false) { observer, lower in
            observer.alertService.setLowerDewPoint(celsius: lower, for: webTag.uuid)
        }
        bind(view.viewModel.dewPointCelsiusUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpperDewPoint(celsius: upper, for: webTag.uuid)
        }
        bind(view.viewModel.dewPointAlertDescription, fire: false) { observer, dewPointAlertDescription in
            observer.alertService.setDewPoint(description: dewPointAlertDescription, for: webTag.uuid)
        }

        // pressure
        let pressureLower = view.viewModel.pressureLowerBound
        let pressureUpper = view.viewModel.pressureUpperBound
        bind(view.viewModel.isPressureAlertOn, fire: false) {
            [weak pressureLower, weak pressureUpper] observer, isOn in
            if let l = pressureLower?.value, let u = pressureUpper?.value {
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
            observer.alertService.setLower(pressure: lower, for: webTag.uuid)
        }

        bind(view.viewModel.pressureUpperBound, fire: false) { observer, upper in
            observer.alertService.setUpper(pressure: upper, for: webTag.uuid)
        }

        bind(view.viewModel.pressureAlertDescription, fire: false) { observer, pressureAlertDescription in
            observer.alertService.setPressure(description: pressureAlertDescription, for: webTag.uuid)
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
        view.viewModel.temperatureUnit.value = settings.temperatureUnit
        view.viewModel.humidityUnit.value = settings.humidityUnit
        view.viewModel.background.value = backgroundPersistence.background(for: webTag.uuid)

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
        view.viewModel.relativeHumidityAlertDescription.value
            = alertService.relativeHumidityDescription(for: webTag.uuid)
        view.viewModel.absoluteHumidityAlertDescription.value
            = alertService.absoluteHumidityDescription(for: webTag.uuid)
        view.viewModel.dewPointAlertDescription.value
            = alertService.dewPointDescription(for: webTag.uuid)
        view.viewModel.pressureAlertDescription.value
            = alertService.pressureDescription(for: webTag.uuid)

        let temperatureAlertType: AlertType = .temperature(lower: 0, upper: 0)
        if case .temperature(let lower, let upper) = alertService.alert(for: webTag.uuid, of: temperatureAlertType) {
            view.viewModel.isTemperatureAlertOn.value = true
            view.viewModel.celsiusLowerBound.value = lower
            view.viewModel.celsiusUpperBound.value = upper
        } else {
            view.viewModel.isTemperatureAlertOn.value = false
            if let celsiusLower = alertService.lowerCelsius(for: webTag.uuid) {
                view.viewModel.celsiusLowerBound.value = celsiusLower
            }
            if let celsiusUpper = alertService.upperCelsius(for: webTag.uuid) {
                view.viewModel.celsiusUpperBound.value = celsiusUpper
            }
        }

        let relativeHumidityAlertType: AlertType = .relativeHumidity(lower: 0, upper: 0)
        if case .relativeHumidity(let lower, let upper)
            = alertService.alert(for: webTag.uuid, of: relativeHumidityAlertType) {
            view.viewModel.isRelativeHumidityAlertOn.value = true
            view.viewModel.relativeHumidityLowerBound.value = lower
            view.viewModel.relativeHumidityUpperBound.value = upper
        } else {
            view.viewModel.isRelativeHumidityAlertOn.value = false
            if let realtiveHumidityLower = alertService.lowerRelativeHumidity(for: webTag.uuid) {
               view.viewModel.relativeHumidityLowerBound.value = realtiveHumidityLower
            }
            if let relativeHumidityUpper = alertService.upperRelativeHumidity(for: webTag.uuid) {
               view.viewModel.relativeHumidityUpperBound.value = relativeHumidityUpper
            }
        }

        let absoluteHumidityAlertType: AlertType = .absoluteHumidity(lower: 0, upper: 0)
        if case .absoluteHumidity(let lower, let upper)
            = alertService.alert(for: webTag.uuid, of: absoluteHumidityAlertType) {
            view.viewModel.isAbsoluteHumidityAlertOn.value = true
            view.viewModel.absoluteHumidityLowerBound.value = lower
            view.viewModel.absoluteHumidityUpperBound.value = upper
        } else {
            view.viewModel.isAbsoluteHumidityAlertOn.value = false
            if let absoluteHumidityLower = alertService.lowerAbsoluteHumidity(for: webTag.uuid) {
                view.viewModel.absoluteHumidityLowerBound.value = absoluteHumidityLower
            }
            if let absoluteHumidityUpper = alertService.upperAbsoluteHumidity(for: webTag.uuid) {
                view.viewModel.absoluteHumidityUpperBound.value = absoluteHumidityUpper
            }
        }

        let dewPointAlertType: AlertType = .dewPoint(lower: 0, upper: 0)
        if case .dewPoint(let lower, let upper) = alertService.alert(for: webTag.uuid, of: dewPointAlertType) {
            view.viewModel.isDewPointAlertOn.value = true
            view.viewModel.dewPointCelsiusLowerBound.value = lower
            view.viewModel.dewPointCelsiusUpperBound.value = upper
        } else {
            view.viewModel.isDewPointAlertOn.value = false
            if let dewPointCelsiusLowerBound = alertService.lowerDewPointCelsius(for: webTag.uuid) {
                view.viewModel.dewPointCelsiusLowerBound.value = dewPointCelsiusLowerBound
            }
            if let dewPointCelsiusUpperBound = alertService.upperDewPointCelsius(for: webTag.uuid) {
                view.viewModel.dewPointCelsiusUpperBound.value = dewPointCelsiusUpperBound
            }
        }

        let pressureAlertType: AlertType = .pressure(lower: 0, upper: 0)
        if case .pressure(let lower, let upper) = alertService.alert(for: webTag.uuid, of: pressureAlertType) {
            view.viewModel.isPressureAlertOn.value = true
            view.viewModel.pressureLowerBound.value = lower
            view.viewModel.pressureUpperBound.value = upper
        } else {
            view.viewModel.isPressureAlertOn.value = false
            if let pressureLowerBound = alertService.lowerPressure(for: webTag.uuid) {
                view.viewModel.pressureLowerBound.value = pressureLowerBound
            }
            if let pressureUpperBound = alertService.upperPressure(for: webTag.uuid) {
                view.viewModel.pressureUpperBound.value = pressureUpperBound
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

    // swiftlint:disable:next cyclomatic_complexity
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
                    switch type {
                    case .temperature:
                        let isOn = self?.alertService.isOn(type: type, for: uuid)
                        if isOn != self?.view.viewModel.isTemperatureAlertOn.value {
                            self?.view.viewModel.isTemperatureAlertOn.value = isOn
                        }
                    case .relativeHumidity:
                        let isOn = self?.alertService.isOn(type: type, for: uuid)
                        if isOn != self?.view.viewModel.isRelativeHumidityAlertOn.value {
                            self?.view.viewModel.isRelativeHumidityAlertOn.value = isOn
                        }
                    case .absoluteHumidity:
                        let isOn = self?.alertService.isOn(type: type, for: uuid)
                        if isOn != self?.view.viewModel.isAbsoluteHumidityAlertOn.value {
                            self?.view.viewModel.isAbsoluteHumidityAlertOn.value = isOn
                        }
                    case .dewPoint:
                        let isOn = self?.alertService.isOn(type: type, for: uuid)
                        if isOn != self?.view.viewModel.isDewPointAlertOn.value {
                            self?.view.viewModel.isDewPointAlertOn.value = isOn
                        }
                    case .pressure:
                        let isOn = self?.alertService.isOn(type: type, for: uuid)
                        if isOn != self?.view.viewModel.isPressureAlertOn.value {
                            self?.view.viewModel.isPressureAlertOn.value = isOn
                        }
                    case .connection:
                        // do nothing, no connection alert here
                        break
                    case .movement:
                        // do nothing, no movement alert here
                        break
                    }
            }
        })
    }
}
// swiftlint:enable file_length
