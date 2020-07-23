//swiftlint:disable file_length
import Foundation
import RealmSwift
import BTKit
import UIKit
import Charts
import Future

class TagChartsPresenter: TagChartsModuleInput {
    weak var view: TagChartsViewInput!
    var router: TagChartsRouterInput!
    var interactor: TagChartsInteractorInput!
    var errorPresenter: ErrorPresenter!
    var backgroundPersistence: BackgroundPersistence!
    var settings: Settings!
    var foreground: BTForeground!
    var activityPresenter: ActivityPresenter!
    var alertService: AlertService!
    var background: BTBackground!
    var mailComposerPresenter: MailComposerPresenter!
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
    private var backgroundToken: NSObjectProtocol?
    private var alertDidChangeToken: NSObjectProtocol?
    private var didConnectToken: NSObjectProtocol?
    private var didDisconnectToken: NSObjectProtocol?
    private var lnmDidReceiveToken: NSObjectProtocol?
    private var downsampleDidChangeToken: NSObjectProtocol?
    private var chartIntervalDidChangeToken: NSObjectProtocol?
    private var lastSyncViewModelDate = Date()
    private var lastChartSyncDate = Date()
    private var ruuviTag: AnyRuuviTagSensor! {
        didSet {
            syncViewModel()
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
        backgroundToken?.invalidate()
        alertDidChangeToken?.invalidate()
        didConnectToken?.invalidate()
        didDisconnectToken?.invalidate()
        lnmDidReceiveToken?.invalidate()
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
        startListeningToAlertStatus()
        startObservingDidConnectDisconnectNotifications()
        startObservingLocalNotificationsManager()
    }

    func viewWillAppear() {
        startObservingBluetoothState()
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
            router.openTagSettings(ruuviTag: ruuviTag, humidity: nil, output: self)
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
            self?.view.showExportSheet(with: url)
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        }, completion: { [weak self] in
            self?.isLoading = false
        })
    }

    func viewDidTriggerClear(for viewModel: TagChartsViewModel) {
        view.showClearConfirmationDialog(for: viewModel)
    }

    func viewDidConfirmToSync(for viewModel: TagChartsViewModel) {
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
        let op = interactor.deleteAllRecords(ruuviTagId: ruuviTag.id)
        op.on(failure: {[weak self] (error) in
            self?.errorPresenter.present(error: error)
        }, completion: { [weak self] in
             self?.isLoading = false
        })
    }
}
// MARK: - TagChartsInteractorOutput
extension TagChartsPresenter: TagChartsInteractorOutput {
    func interactorDidError(_ error: RUError) {
        errorPresenter.present(error: error)
    }
}
// MARK: - DiscoverModuleOutput
extension TagChartsPresenter: DiscoverModuleOutput {
    func discover(module: DiscoverModuleInput, didAddWebTag provider: WeatherProvider) {
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
}

// MARK: - AlertServiceObserver
extension TagChartsPresenter: AlertServiceObserver {
    func alert(service: AlertService, isTriggered: Bool, for uuid: String) {
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
        if UIApplication.shared.statusBarOrientation.isLandscape
            && !settings.tagChartsLandscapeSwipeInstructionWasShown {
            settings.tagChartsLandscapeSwipeInstructionWasShown = true
            view.showSwipeUpInstruction()
        }
    }

    private func syncViewModel() {
        viewModel = TagChartsViewModel(ruuviTag)
        if let luid = ruuviTag.luid {
            viewModel.name.value = ruuviTag.name
            viewModel.background.value = backgroundPersistence.background(for: luid)
            viewModel.isConnected.value = background.isConnected(uuid: luid.value)
            viewModel.alertState.value = alertService.hasRegistrations(for: luid.value)
                                                                ? .registered : .empty
        } else if let macId = ruuviTag.macId {
            // FIXME
            // viewModel.background.value = backgroundPersistence.background(for: macId)
            // viewModel.alertState.value = alertService.hasRegistrations(for: luid.value) ? .registered : .empty
             viewModel.isConnected.value = false
        } else {
            assertionFailure()
        }
    }
    private func restartObservingData() {
        interactor.configure(withTag: ruuviTag)
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
            if let userInfo = notification.userInfo,
                let luid = userInfo[BPDidChangeBackgroundKey.luid] as? LocalIdentifier,
                            self?.viewModel.uuid.value == luid.value {
                self?.viewModel.background.value = self?.backgroundPersistence.background(for: luid)
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
            .addObserver(forName: .AlertServiceAlertDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
            if let sSelf = self,
                let userInfo = notification.userInfo,
                let uuid = userInfo[AlertServiceAlertDidChangeKey.uuid] as? String,
                self?.viewModel.uuid.value == uuid {
                if sSelf.alertService.hasRegistrations(for: uuid) {
                    self?.viewModel.alertState.value = .registered
                } else {
                    self?.viewModel.alertState.value = .empty
                }
            }
        })
    }

    private func startListeningToAlertStatus() {
        if let luid = ruuviTag.luid {
            alertService.subscribe(self, to: luid.value)
        } else if let macId = ruuviTag.macId {
            // FIXME
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
}
//swiftlint:enable file_length
