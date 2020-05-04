// swiftlint:disable file_length
import Foundation
import RealmSwift
import BTKit
import UIKit
import Charts

class TagChartsPresenter: TagChartsModuleInput {
    weak var view: TagChartsViewInput!
    var router: TagChartsRouterInput!
    var errorPresenter: ErrorPresenter!
    var backgroundPersistence: BackgroundPersistence!
    var settings: Settings!
    var foreground: BTForeground!
    var activityPresenter: ActivityPresenter!
    var ruuviTagService: RuuviTagService!
    var gattService: GATTService!
    var exportService: ExportService!
    var alertService: AlertService!
    var background: BTBackground!
    var mailComposerPresenter: MailComposerPresenter!
    var feedbackEmail: String!
    var feedbackSubject: String!
    var infoProvider: InfoProvider!
    var ruuviTagReactor: RuuviTagReactor!
    var ruuviTagTank: RuuviTagTank!

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
    private var ruuviTagToken: RUObservationToken?
    private var ruuviTagDataToken: RUObservationToken?
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
    private let threshold: Int = 100
    private var ruuviTagData: [RuuviMeasurement] = [] {
        didSet {
            if let last = ruuviTagData.last {
                lastMeasurement = last
            } else if let last = oldValue.last {
                lastMeasurement = last
            } else if let last = lastMeasurement,
                ruuviTagData.isEmpty {
                ruuviTagData.append(last)
            }
        }
    }
    private var lastMeasurement: RuuviMeasurement?

    private var ruuviTags = [AnyRuuviTagSensor]()
    private var viewModel = TagChartsViewModel(type: .ruuvi) {
        didSet {
            self.view.viewModel = self.viewModel
        }
    }
    private var tagUUID: String? {
        didSet {
            if let tagUUID = tagUUID {
                output?.tagCharts(module: self, didScrollTo: tagUUID)
            }
        }
    }
    private var tagIsConnectable: Bool {
        if let ruuviTag = ruuviTags.first(where: {$0.id == tagUUID}) {
            return ruuviTag.isConnectable
        } else {
            return false
        }
    }
    deinit {
        ruuviTagToken?.invalidate()
        stateToken?.invalidate()
        ruuviTagDataToken?.invalidate()
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

    func configure(uuid: String) {
        self.tagUUID = uuid
    }

    func dismiss() {
        router.dismiss()
    }
}

extension TagChartsPresenter: TagChartsViewOutput {

    func viewDidLoad() {
        startObservingRuuviTags()
        startListeningToSettings()
        startObservingBackgroundChanges()
        startObservingAlertChanges()
        startObservingDidConnectDisconnectNotifications()
        startObservingLocalNotificationsManager()
    }

    func viewWillAppear() {
        startObservingBluetoothState()
        tryToShowSwipeUpHint()
        restartObservingData()
    }

    func viewWillDisappear() {
        stopObservingBluetoothState()
        stopObservingRuuviTagsData()
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
        if viewModel.type == .ruuvi, let ruuviTag = ruuviTags.first(where: { $0.luid == viewModel.uuid.value }) {
            router.openTagSettings(ruuviTag: ruuviTag, humidity: nil)
        } else {
            assert(false)
        }
    }

    func viewDidScroll(to viewModel: TagChartsViewModel) {
        if let uuid = viewModel.uuid.value {
            tagUUID = uuid
        } else {
            assert(false)
        }
    }

    func viewDidTriggerSync(for viewModel: TagChartsViewModel) {
        view.showSyncConfirmationDialog(for: viewModel)
    }

    func viewDidTriggerExport(for viewModel: TagChartsViewModel) {
        if let uuid = viewModel.uuid.value {
            isLoading = true
            exportService.csvLog(for: uuid).on(success: { [weak self] url in
                self?.view.showExportSheet(with: url)
            }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.isLoading = false
            })
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidTriggerClear(for viewModel: TagChartsViewModel) {
        view.showClearConfirmationDialog(for: viewModel)
    }

    func viewDidConfirmToSync(for viewModel: TagChartsViewModel) {
        if let uuid = viewModel.uuid.value, let mac = viewModel.mac.value {
            isSyncing = true
            let connectionTimeout: TimeInterval = settings.connectionTimeout
            let serviceTimeout: TimeInterval = settings.serviceTimeout
            let op = gattService.syncLogs(uuid: uuid, mac: mac, progress: { [weak self] progress in
                DispatchQueue.main.async { [weak self] in
                    self?.view.setSync(progress: progress, for: viewModel)
                }
            }, connectionTimeout: connectionTimeout, serviceTimeout: serviceTimeout)
            op.on(success: { [weak self] _ in
                self?.view.setSync(progress: nil, for: viewModel)
                self?.ruuviTagData = []
                #warning("TODO: add clear charts data")
                self?.restartObservingData()
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
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidConfirmToClear(for viewModel: TagChartsViewModel) {
        if let mac = viewModel.mac.value {
            isLoading = true
            let op = ruuviTagTank.deleteAllRecords(mac)
            op.on(failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.stopObservingRuuviTagsData()
                self?.ruuviTagData = []
                self?.restartObservingData()
                self?.isLoading = false
            })
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
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

// MARK: - Private
extension TagChartsPresenter {

    private func tryToShowSwipeUpHint() {
        if UIApplication.shared.statusBarOrientation.isLandscape
            && !settings.tagChartsLandscapeSwipeInstructionWasShown {
            settings.tagChartsLandscapeSwipeInstructionWasShown = true
            view.showSwipeUpInstruction()
        }
    }

    private func syncViewModels() {
        guard let tagId = self.tagUUID,
            let ruuviTag = ruuviTags.first(where: {$0.id == tagId}) else {
            return
        }
        viewModel = TagChartsViewModel(ruuviTag)
        viewModel.background.value = backgroundPersistence.background(for: ruuviTag.id)
        viewModel.isConnected.value = background.isConnected(uuid: ruuviTag.id)
        viewModel.alertState.value = alertService
            .hasRegistrations(for: ruuviTag.id) ? .registered : .empty
//        viewModel.temperatureUnit.value = settings.temperatureUnit
//        viewModel.humidityUnit.value = settings.humidityUnit
        // if no tags, open discover
        if ruuviTags.count == 0 {
            router.openDiscover(output: self)
            stopObservingRuuviTagsData()
        } else {
            restartObservingData()
        }
    }

    private func restartObservingData() {
        ruuviTagDataToken?.invalidate()
        guard let uuid = tagUUID else { return }
        ruuviTagDataToken = ruuviTagReactor.observe(uuid, { [weak self] results in
//            self?.handleInitialRuuviTagData(results)
        })
//        ruuviTagDataToken = ruuviTagDataRealm.observe {
//            [weak self] (change) in
//            switch change {
//            case .initial(let results):
//                self?.isLoading = true
//                if results.isEmpty {
//                    self?.handleEmptyResults()
//                } else {
//                    self?.handleInitialRuuviTagData(results)
//                }
//                self?.isLoading = false
//            case .update(let results, _, let insertions, _):
//                // sync every 1 second
//                self?.isSyncing = false
//                if insertions.isEmpty {
//                    self?.handleEmptyResults()
//                } else {
//                    self?.handleUpdateRuuviTagData(results, insertions: insertions)
//                }
//            default:
//                break
//            }
//        }
    }


    private func startObservingRuuviTags() {
        ruuviTagToken?.invalidate()
        ruuviTagToken = ruuviTagReactor.observe({ [weak self] change in
            switch change {
            case .initial(let ruuviTags):
                self?.ruuviTags = ruuviTags.map({ $0.any })
                self?.syncViewModels()
                self?.startListeningToAlertStatus()
                if let uuid = self?.tagUUID {
                    self?.configure(uuid: uuid)
                } else if let uuid = ruuviTags.first?.id {
                    self?.configure(uuid: uuid)
                }
                self?.restartObservingData()
            default:
                break
            }
        })
//        ruuviTags = realmContext.main.objects(RuuviTagRealm.self)
//            .filter("isConnectable == true")
//        ruuviTagsToken?.invalidate()
//        ruuviTagsToken = ruuviTags?.observe { [weak self] (change) in
//            switch change {
//            case .initial(let ruuviTags):
//                if let uuid = self?.tagUUID {
//                    self?.configure(uuid: uuid)
//                } else if let uuid = ruuviTags.first?.uuid {
//                    self?.configure(uuid: uuid)
//                }
//                self?.restartObservingData()
//            case .update(let ruuviTags, _, let insertions, _):
//                self?.ruuviTags = ruuviTags
//                if let ii = insertions.last {
//                    let uuid = ruuviTags[ii].uuid
//                    if let index = self?.viewModels.firstIndex(where: { $0.uuid.value == uuid }) {
//                        self?.view.scroll(to: index)
//                    }
//                }
//                if let uuid = self?.tagUUID {
//                    let tagUUIDs = ruuviTags.compactMap({$0.uuid})
//                    if !tagUUIDs.contains(uuid),
//                        let lastTagUUID = tagUUIDs.last {
//                        self?.configure(uuid: lastTagUUID)
//                    }
//                } else {
//                    if let lastTagUUID = ruuviTags.compactMap({$0.uuid}).last {
//                        self?.configure(uuid: lastTagUUID)
//                    }
//                }
//                self?.restartObservingData()
//            case .error(let error):
//                self?.errorPresenter.present(error: error)
//            }
//        }
    }

    private func stopObservingRuuviTagsData() {
        ruuviTagDataToken?.invalidate()
    }

    private func startListeningToSettings() {
        temperatureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .TemperatureUnitDidChange,
                         object: nil,
                         queue: .main) { [weak self] _ in
//            self?.viewModel.temperatureUnit.value = self?.settings.temperatureUnit
            self?.restartObservingData()
        }
        humidityUnitToken = NotificationCenter
            .default
            .addObserver(forName: .HumidityUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
//            self?.viewModel.humidityUnit.value = self?.settings.humidityUnit
            self?.restartObservingData()
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
                    self?.viewModel.alertState.value = sSelf.alertService.hasRegistrations(for: uuid) ? .registered : .empty
            }
        })
    }

    private func startListeningToAlertStatus() {
        ruuviTags.forEach({ alertService.subscribe(self, to: $0.id) })
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

    static func newDataSet() -> LineChartDataSet {
        let lineChartDataSet = LineChartDataSet()
        lineChartDataSet.axisDependency = .left
        lineChartDataSet.setColor(UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1))
        lineChartDataSet.lineWidth = 1.5
        lineChartDataSet.drawCirclesEnabled = true
        lineChartDataSet.drawValuesEnabled = false
        lineChartDataSet.fillAlpha = 0.26
        lineChartDataSet.fillColor = UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)
        lineChartDataSet.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        lineChartDataSet.drawCircleHoleEnabled = false
        lineChartDataSet.drawFilledEnabled = true
        lineChartDataSet.highlightEnabled = false
        return lineChartDataSet
    }
}
// swiftlint:enable file_length
