// swiftlint:disable file_length
import Foundation
import BTKit
import UIKit
import Charts
import Future
import RuuviOntology
import RuuviStorage
import RuuviReactor
import RuuviLocal
import RuuviService
import RuuviVirtual
import RuuviNotification
import RuuviNotifier

class TagChartsPresenter: NSObject, TagChartsModuleInput {
    weak var view: TagChartsViewInput!
    var router: TagChartsRouterInput!
    var interactor: TagChartsInteractorInput!

    var errorPresenter: ErrorPresenter!
    var settings: RuuviLocalSettings!
    var foreground: BTForeground!
    var ruuviStorage: RuuviStorage!
    var ruuviReactor: RuuviReactor!
    var activityPresenter: ActivityPresenter!
    var alertPresenter: AlertPresenter!
    var mailComposerPresenter: MailComposerPresenter!
    var ruuviSensorPropertiesService: RuuviServiceSensorProperties!

    var alertService: RuuviServiceAlert!
    var alertHandler: RuuviServiceNotifier!
    var background: BTBackground!

    var feedbackEmail: String!
    var feedbackSubject: String!
    var infoProvider: InfoProvider!

    private var isSyncing: Bool = false
    var isLoading: Bool = false {
        didSet {
            if isLoading {
                activityPresenter.increment()
            } else {
                activityPresenter.decrement()
            }
        }
    }
    private var output: TagChartsModuleOutput?
    private var stateToken: ObservationToken?
    private var temperatureUnitToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
    private var pressureUnitToken: NSObjectProtocol?
    private var backgroundToken: NSObjectProtocol?
    private var alertDidChangeToken: NSObjectProtocol?
    private var didConnectToken: NSObjectProtocol?
    private var didDisconnectToken: NSObjectProtocol?
    private var lnmDidReceiveToken: NSObjectProtocol?
    private var cloudSyncToken: NSObjectProtocol?
    private var downsampleDidChangeToken: NSObjectProtocol?
    private var chartIntervalDidChangeToken: NSObjectProtocol?
    private var sensorSettingsToken: RuuviReactorToken?
    private var lastSyncViewModelDate = Date()
    private var lastChartSyncDate = Date()
    private var exportFileUrl: URL?
    private var ruuviTag: AnyRuuviTagSensor! {
        didSet {
            syncViewModel()
        }
    }

    private var sensorSettings: SensorSettings! {
        didSet {
            interactor.updateSensorSettings(settings: sensorSettings)
        }
    }

    private var viewModel = TagChartsViewModel(type: .ruuvi) {
        didSet {
            self.view.viewModel = self.viewModel
        }
    }
    deinit {
        stateToken?.invalidate()
        temperatureUnitToken?.invalidate()
        humidityUnitToken?.invalidate()
        pressureUnitToken?.invalidate()
        backgroundToken?.invalidate()
        alertDidChangeToken?.invalidate()
        didConnectToken?.invalidate()
        didDisconnectToken?.invalidate()
        lnmDidReceiveToken?.invalidate()
        cloudSyncToken?.invalidate()
        downsampleDidChangeToken?.invalidate()
        chartIntervalDidChangeToken?.invalidate()
    }

    func configure(output: TagChartsModuleOutput) {
        self.output = output
    }

    func configure(ruuviTag: AnyRuuviTagSensor) {
        self.ruuviTag = ruuviTag
    }

    func dismiss(completion: (() -> Void)? = nil) {
        router.dismiss(completion: completion)
    }
}

extension TagChartsPresenter: TagChartsViewOutput {

    func viewDidLoad() {
        startListeningToSettings()
        startObservingBackgroundChanges()
        startObservingAlertChanges()
        startObservingDidConnectDisconnectNotifications()
        startObservingLocalNotificationsManager()
        startObservingSensorSettingsChanges()
        startObservingCloudSyncNotification()
    }

    func viewWillAppear() {
        startObservingBluetoothState()
        startListeningToAlertStatus()
        tryToShowSwipeUpHint()
        restartObservingData()
        interactor.restartObservingTags()
        syncChartViews()
    }

    func viewWillDisappear() {
        stopObservingBluetoothState()
        interactor.stopObservingTags()
        interactor.stopObservingRuuviTagsData()
    }
    func syncChartViews() {
        view?.setupChartViews(chartViews: interactor.chartViews)
    }
    func viewDidTransition() {
        tryToShowSwipeUpHint()
    }

    func viewDidTriggerMenu() {
        router.openMenu(output: self)
    }

    func viewDidTriggerCards(for viewModel: TagChartsViewModel) {
        router.dismiss()
    }

    func viewDidTriggerSettings(for viewModel: TagChartsViewModel) {
        if viewModel.type == .ruuvi,
            ruuviTag.luid?.value == viewModel.uuid.value {
            router.openTagSettings(ruuviTag: ruuviTag,
                                   temperature: interactor.lastMeasurement?.temperature,
                                   humidity: interactor.lastMeasurement?.humidity,
                                   sensor: sensorSettings,
                                   output: self)
        } else {
            assert(false)
        }
    }

    func viewDidTriggerSync(for viewModel: TagChartsViewModel) {
        view.showSyncConfirmationDialog(for: viewModel)
    }

    func viewDidTriggerExport(for viewModel: TagChartsViewModel) {
        isLoading = true
        interactor.export().on(success: { [weak self] url in
            #if targetEnvironment(macCatalyst)
            guard let sSelf = self else {
                fatalError()
            }
            sSelf.exportFileUrl = url
            sSelf.router.macCatalystExportFile(with: url, delegate: sSelf)
            #else
            self?.view.showExportSheet(with: url)
            #endif
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        }, completion: { [weak self] in
            self?.isLoading = false
        })
    }

    func viewDidTriggerClear(for viewModel: TagChartsViewModel) {
        view.showClearConfirmationDialog(for: viewModel)
    }

    func viewDidConfirmToSyncWithTag(for viewModel: TagChartsViewModel) {
        isSyncing = true
        let connectionTimeout: TimeInterval = settings.connectionTimeout
        let serviceTimeout: TimeInterval = settings.serviceTimeout
        let op = interactor.syncRecords { [weak self] progress in
            DispatchQueue.main.async { [weak self] in
                self?.view.setSync(progress: progress, for: viewModel)
            }
        }
        op.on(success: { [weak self] _ in
            self?.view.setSync(progress: nil, for: viewModel)
            self?.interactor.restartObservingData()
        }, failure: { [weak self] error in
            self?.view.setSync(progress: nil, for: viewModel)
            if case .btkit(.logic(.connectionTimedOut)) = error {
                self?.view.showFailedToSyncIn(connectionTimeout: connectionTimeout)
            } else if case .btkit(.logic(.serviceTimedOut)) = error {
                self?.view.showFailedToServeIn(serviceTimeout: serviceTimeout)
            } else {
                self?.errorPresenter.present(error: error)
            }
        }, completion: {
            DispatchQueue.main.async { [weak self] in
                self?.view.setSync(progress: nil, for: viewModel)
            }
        })
    }

    func viewDidConfirmToClear(for viewModel: TagChartsViewModel) {
        isLoading = true
        interactor.deleteAllRecords(for: ruuviTag)
            .on(failure: {[weak self] (error) in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                 self?.isLoading = false
            })
    }

    func viewDidLocalized() {
        interactor.notifyDidLocalized()
    }
}
// MARK: - TagChartsInteractorOutput
extension TagChartsPresenter: TagChartsInteractorOutput {
    func interactorDidError(_ error: RUError) {
        errorPresenter.present(error: error)
    }

    func interactorDidUpdate(sensor: AnyRuuviTagSensor) {
        self.ruuviTag = sensor
    }

    func interactorDidSyncComplete(_ recordsCount: Int) {
        let okAction = UIAlertAction(title: "OK".localized(),
                                     style: .default,
                                     handler: nil)
        let title, message: String
        if recordsCount > 0 {
            title = "TagCharts.Status.Success".localized()
            message = String(format: "TagChartsPresenter.NumberOfPointsSynchronizedOverNetwork".localized(),
                             String(recordsCount))
        } else {
            title = "TagChartsPresenter.NetworkSync".localized()
            message = "TagChartsPresenter.NoNewMeasurementsFromNetwork".localized()
        }

        let alertViewModel: AlertViewModel = AlertViewModel(
            title: title,
            message: message,
            style: .alert,
            actions: [okAction])
        alertPresenter.showAlert(alertViewModel)
    }
}
// MARK: - DiscoverModuleOutput
extension TagChartsPresenter: DiscoverModuleOutput {
    func discover(module: DiscoverModuleInput, didAddNetworkTag mac: String) {
        module.dismiss { [weak self] in
            self?.router.dismiss()
        }
    }

    func discover(module: DiscoverModuleInput, didAddWebTag provider: VirtualProvider) {
        module.dismiss { [weak self] in
            self?.router.dismiss()
        }
    }

    func discover(module: DiscoverModuleInput, didAddWebTag location: Location) {
        module.dismiss { [weak self] in
            self?.router.dismiss()
        }
    }

    func discover(module: DiscoverModuleInput, didAdd ruuviTag: RuuviTag) {
        module.dismiss { [weak self] in
            self?.router.dismiss()
        }
    }
}

// MARK: - MenuModuleOutput
extension TagChartsPresenter: MenuModuleOutput {
    func menu(module: MenuModuleInput, didSelectAddRuuviTag sender: Any?) {
        module.dismiss()
        router.openDiscover(output: self)
    }

    func menu(module: MenuModuleInput, didSelectSettings sender: Any?) {
        module.dismiss()
        router.openSettings()
    }

    func menu(module: MenuModuleInput, didSelectAbout sender: Any?) {
        module.dismiss()
        router.openAbout()
    }

    func menu(module: MenuModuleInput, didSelectGetMoreSensors sender: Any?) {
        module.dismiss()
        router.openRuuviWebsite()
    }

    func menu(module: MenuModuleInput, didSelectFeedback sender: Any?) {
        module.dismiss()
        infoProvider.summary { [weak self] summary in
            guard let sSelf = self else { return }
            sSelf.mailComposerPresenter.present(email: sSelf.feedbackEmail,
                                                subject: sSelf.feedbackSubject,
                                                body: "\n\n" + summary)
        }
    }

    func menu(module: MenuModuleInput, didSelectSignIn sender: Any?) {
        module.dismiss()
        router.openSignIn(output: self)
    }

    func menu(module: MenuModuleInput, didSelectOpenConfig sender: Any?) {
        module.dismiss()
    }
}

// MARK: - SignInModuleOutput
extension TagChartsPresenter: SignInModuleOutput {
    func signIn(module: SignInModuleInput, didSuccessfulyLogin sender: Any?) {
        module.dismiss()
    }
}

// MARK: - RuuviServiceNotifierObserver
extension TagChartsPresenter: RuuviServiceNotifierObserver {
    func ruuviNotifier(service: RuuviServiceNotifier, isTriggered: Bool, for uuid: String) {
        let newValue: AlertState = isTriggered ? .firing : .registered
        if newValue != viewModel.alertState.value {
            viewModel.alertState.value = newValue
        }
    }
}

// MARK: - TagSettingsModuleOutput
extension TagChartsPresenter: TagSettingsModuleOutput {
    func tagSettingsDidDeleteTag(module: TagSettingsModuleInput,
                                 ruuviTag: RuuviTagSensor) {
        module.dismiss { [weak self] in
            guard let sSelf = self else {
                return
            }
            sSelf.output?.tagChartsDidDeleteTag(module: sSelf)
        }
    }
}

// MARK: - Private
extension TagChartsPresenter {

    private func tryToShowSwipeUpHint() {
        if UIWindow.isLandscape
            && !settings.tagChartsLandscapeSwipeInstructionWasShown {
            settings.tagChartsLandscapeSwipeInstructionWasShown = true
            view.showSwipeUpInstruction()
        }
    }

    private func syncViewModel() {
        let viewModel = TagChartsViewModel(ruuviTag)
        ruuviSensorPropertiesService.getImage(for: ruuviTag)
            .on(success: { image in
                viewModel.background.value = image
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
        if let luid = ruuviTag.luid {
            viewModel.name.value = ruuviTag.name
            viewModel.isConnected.value = background.isConnected(uuid: luid.value)
            // get lastest sensorSettings
            ruuviStorage.readSensorSettings(ruuviTag).on { settings in
                self.sensorSettings = settings
            }
        } else if ruuviTag.macId != nil {
            viewModel.isConnected.value = false
        } else {
            assertionFailure()
        }
        viewModel.alertState.value = alertService.hasRegistrations(for: ruuviTag) ? .registered : .empty
        self.viewModel = viewModel
    }
    private func restartObservingData() {
        interactor.configure(withTag: ruuviTag, andSettings: sensorSettings)
        interactor.restartObservingData()
    }
    private func startListeningToSettings() {
        temperatureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .TemperatureUnitDidChange,
                         object: nil,
                         queue: .main) { [weak self] _ in
            self?.interactor.restartObservingData()
            self?.interactor.notifySettingsChanged()
        }
        humidityUnitToken = NotificationCenter
            .default
            .addObserver(forName: .HumidityUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
            self?.interactor.restartObservingData()
            self?.interactor.notifySettingsChanged()
        })
        pressureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .PressureUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
            self?.interactor.restartObservingData()
            self?.interactor.notifySettingsChanged()
        })
        downsampleDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .DownsampleOnDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
            self?.interactor.notifyDownsamleOnDidChange()
        })
        chartIntervalDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .ChartIntervalDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
            self?.interactor.notifyDownsamleOnDidChange()
        })
    }

    private func startObservingBackgroundChanges() {
        backgroundToken = NotificationCenter
            .default
            .addObserver(forName: .BackgroundPersistenceDidChangeBackground,
                         object: nil,
                         queue: .main) { [weak self] notification in
                guard let sSelf = self else { return }
                if let userInfo = notification.userInfo {
                    let luid = userInfo[BPDidChangeBackgroundKey.luid] as? LocalIdentifier
                    let macId = userInfo[BPDidChangeBackgroundKey.macId] as? MACIdentifier
                    if sSelf.viewModel.uuid.value == luid?.value || sSelf.viewModel.mac.value == macId?.value {
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

    private func startObservingBluetoothState() {
        stateToken = foreground.state(self, closure: { (observer, state) in
            if state != .poweredOn {
                observer.view.showBluetoothDisabled()
            }
        })
    }

    private func stopObservingBluetoothState() {
        stateToken?.invalidate()
    }

    private func startObservingAlertChanges() {
        alertDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .RuuviServiceAlertDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
            if let sSelf = self,
                let userInfo = notification.userInfo,
                let physicalSensor = userInfo[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor,
                self?.viewModel.mac.value == physicalSensor.macId?.value {
                if sSelf.alertService.hasRegistrations(for: physicalSensor) {
                    self?.viewModel.alertState.value = .registered
                } else {
                    self?.viewModel.alertState.value = .empty
                }
            }
        })
    }

    private func startListeningToAlertStatus() {
        if let luid = ruuviTag.luid {
            alertHandler.subscribe(self, to: luid.value)
        } else if let macId = ruuviTag.macId {
            alertHandler.subscribe(self, to: macId.value)
        } else {
            assertionFailure()
        }
    }

    func startObservingDidConnectDisconnectNotifications() {
        didConnectToken = NotificationCenter
            .default
            .addObserver(forName: .BTBackgroundDidConnect,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                                let uuid = userInfo[BTBackgroundDidConnectKey.uuid] as? String,
                                self?.viewModel.uuid.value == uuid {
                                self?.viewModel.isConnected.value = true
                            }
            })

        didDisconnectToken = NotificationCenter
            .default
            .addObserver(forName: .BTBackgroundDidDisconnect,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                                let uuid = userInfo[BTBackgroundDidDisconnectKey.uuid] as? String,
                                self?.viewModel.uuid.value == uuid {
                                self?.viewModel.isConnected.value = false
                            }
            })
    }

    private func startObservingSensorSettingsChanges() {
        sensorSettingsToken = ruuviReactor.observe(ruuviTag, { (reactorChange) in
            switch reactorChange {
            case .update(let settings):
                self.sensorSettings = settings
            case .insert(let sensorSettings):
                self.sensorSettings = sensorSettings
            default: break
            }
        })
    }

    private func startObservingLocalNotificationsManager() {
        lnmDidReceiveToken = NotificationCenter
            .default
            .addObserver(forName: .LNMDidReceive,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let uuid = notification.userInfo?[LNMDidReceiveKey.uuid] as? String ,
                            self?.viewModel.uuid.value != uuid {
                                self?.dismiss()
                            }
            })
    }

    private func startObservingCloudSyncNotification() {
        cloudSyncToken = NotificationCenter
            .default
            .addObserver(forName: .NetworkSyncDidChangeStatus,
                         object: nil,
                         queue: .main,
                         using: { [weak self] notification in
            guard let mac = notification.userInfo?[NetworkSyncStatusKey.mac] as? MACIdentifier,
                  let status = notification.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus,
                  status == .complete,
                  mac.any == self?.ruuviTag.macId?.any else {
                return
            }
            self?.interactor.restartObservingData()
        })
    }
}

extension TagChartsPresenter: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = exportFileUrl {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
// swiftlint:enable file_length
