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
    private var isLoading: Bool = false {
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
    private var lastSyncViewModelDate = Date()
    private var lastChartSyncDate = Date()
    private var ruuviTag: AnyRuuviTagSensor! {
        didSet {
            interactor.configure(withTag: ruuviTag)
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
        if let settingsToken = temperatureUnitToken {
            NotificationCenter.default.removeObserver(settingsToken)
        }
        if let humidityUnitToken = humidityUnitToken {
            NotificationCenter.default.removeObserver(humidityUnitToken)
        }
        if let backgroundToken = backgroundToken {
            NotificationCenter.default.removeObserver(backgroundToken)
        }
        if let alertDidChangeToken = alertDidChangeToken {
            NotificationCenter.default.removeObserver(alertDidChangeToken)
        }
        if let didConnectToken = didConnectToken {
            NotificationCenter.default.removeObserver(didConnectToken)
        }
        if let didDisconnectToken = didDisconnectToken {
            NotificationCenter.default.removeObserver(didDisconnectToken)
        }
        if let lnmDidReceiveToken = lnmDidReceiveToken {
            NotificationCenter.default.removeObserver(lnmDidReceiveToken)
        }
    }

    func configure(output: TagChartsModuleOutput) {
        self.output = output
    }

    func configure(ruuviTag: AnyRuuviTagSensor) {
        self.ruuviTag = ruuviTag
    }

    func dismiss() {
        router.dismiss()
    }
}

extension TagChartsPresenter: TagChartsViewOutput {

    func viewDidLoad() {
        createChartViews()
        startListeningToSettings()
        startObservingBackgroundChanges()
        startObservingAlertChanges()
        startObservingDidConnectDisconnectNotifications()
        startObservingLocalNotificationsManager()
    }

    func viewWillAppear() {
        startObservingBluetoothState()
        tryToShowSwipeUpHint()
        interactor?.restartObservingData()
    }

    func viewWillDisappear() {
        stopObservingBluetoothState()
        interactor?.stopObservingRuuviTagsData()
    }
    func createChartViews() {
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
            ruuviTag.luid == viewModel.uuid.value {
            router.openTagSettings(ruuviTag: ruuviTag, humidity: nil)
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
        })
    }

    func viewDidConfirmToClear(for viewModel: TagChartsViewModel) {
        isLoading = true
        let op = interactor.deleteAllRecords()
        op.on(failure: {[weak self] (error) in
            self?.errorPresenter.present(error: error)
        }, completion: { [weak self] in
             self?.isLoading = false
        })
    }
}
// MARK: - TagChartsInteractorOutput
extension TagChartsPresenter: TagChartsInteractorOutput {
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
        viewModel.background.value = backgroundPersistence.background(for: ruuviTag.id)
        viewModel.isConnected.value = background.isConnected(uuid: ruuviTag.id)
        viewModel.alertState.value = alertService
            .hasRegistrations(for: ruuviTag.id) ? .registered : .empty
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
    }

    private func startObservingBackgroundChanges() {
        backgroundToken = NotificationCenter
            .default
            .addObserver(forName: .BackgroundPersistenceDidChangeBackground,
                         object: nil,
                         queue: .main) { [weak self] notification in
            if let userInfo = notification.userInfo,
                let uuid = userInfo[BPDidChangeBackgroundKey.uuid] as? String,
                self?.viewModel.uuid.value == uuid {
                self?.viewModel.background.value = self?.backgroundPersistence.background(for: uuid)
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
        alertService.subscribe(self, to: ruuviTag.id)
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
