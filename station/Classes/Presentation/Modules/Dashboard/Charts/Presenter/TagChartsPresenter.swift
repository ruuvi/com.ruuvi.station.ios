// swiftlint:disable file_length
import Foundation
import RealmSwift
import BTKit
import UIKit

class TagChartsPresenter: TagChartsModuleInput {
    weak var view: TagChartsViewInput!
    var router: TagChartsRouterInput!
    var realmContext: RealmContext!
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

    private var isLoading: Bool = false {
        didSet {
            if isLoading != oldValue {
                if isLoading {
                    activityPresenter.increment()
                } else {
                    activityPresenter.decrement()
                }
            }
        }
    }
    private var output: TagChartsModuleOutput?
    private var ruuviTagsToken: NotificationToken?
    private var stateToken: ObservationToken?
    private var ruuviTagDataTokens = [NotificationToken]()
    private var temperatureUnitToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
    private var backgroundToken: NSObjectProtocol?
    private var alertDidChangeToken: NSObjectProtocol?
    private var didConnectToken: NSObjectProtocol?
    private var didDisconnectToken: NSObjectProtocol?
    private var lnmDidReceiveToken: NSObjectProtocol?
    private var lastSyncViewModelDate = Date()
    
    private var ruuviTags: Results<RuuviTagRealm>? {
        didSet {
            syncViewModels()
            startListeningToAlertStatus()
        }
    }
    private var viewModels = [TagChartsViewModel]() {
        didSet {
            view.viewModels = viewModels
        }
    }
    private var tagUUID: String? {
        didSet {
            if let tagUUID = tagUUID {
                output?.tagCharts(module: self, didScrollTo: tagUUID)
                scrollToCurrentTag()
            }
        }
    }
    private var tagIsConnectable: Bool {
        if let ruuviTag = ruuviTags?.first(where: {$0.uuid == tagUUID}) {
            return ruuviTag.isConnectable
        } else {
            return false
        }
    }
    deinit {
        ruuviTagsToken?.invalidate()
        stateToken?.invalidate()
        ruuviTagDataTokens.forEach({ $0.invalidate() })
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
    }

    func viewWillDisappear() {
        stopObservingBluetoothState()
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
        if viewModel.type == .ruuvi, let ruuviTag = ruuviTags?.first(where: { $0.uuid == viewModel.uuid.value }) {
            router.openTagSettings(ruuviTag: ruuviTag, humidity: viewModel.relativeHumidity.value?.last?.value)
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
            exportService.csvLog(for: uuid).on(success: { [weak self] url in
                self?.view.showExportSheet(with: url)
            }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            })
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidTriggerClear(for viewModel: TagChartsViewModel) {
        view.showClearConfirmationDialog(for: viewModel)
    }

    func viewDidConfirmToSync(for viewModel: TagChartsViewModel) {
        if let uuid = viewModel.uuid.value {
            let connectionTimeout: TimeInterval = settings.connectionTimeout
            let serviceTimeout: TimeInterval = settings.serviceTimeout
            let op = gattService.syncLogs(with: uuid, progress: { [weak self] progress in
                DispatchQueue.main.async { [weak self] in
                    self?.view.setSync(progress: progress, for: viewModel)
                }
            }, connectionTimeout: connectionTimeout, serviceTimeout: serviceTimeout)
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
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidConfirmToClear(for viewModel: TagChartsViewModel) {
        if let uuid = viewModel.uuid.value {
            let op = ruuviTagService.clearHistory(uuid: uuid)
            op.on(failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
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
        viewModels
            .filter({ $0.uuid.value == uuid })
            .forEach({
                let newValue: AlertState = isTriggered ? .firing : .registered
                if newValue != $0.alertState.value {
                    $0.alertState.value = newValue
                }
            })
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

    private func scrollToCurrentTag() {
        if let index = viewModels.firstIndex(where: { $0.uuid.value == tagUUID }) {
            view.scroll(to: index, immediately: true)
        }
    }

    private func syncViewModels() {
        if ruuviTags != nil {
            viewModels = ruuviTags?.compactMap({ (ruuviTag) -> TagChartsViewModel in
                let viewModel = TagChartsViewModel(ruuviTag)
                viewModel.background.value = backgroundPersistence.background(for: ruuviTag.uuid)
                viewModel.temperatureUnit.value = settings.temperatureUnit
                viewModel.humidityUnit.value = settings.humidityUnit
                viewModel.isConnected.value = background.isConnected(uuid: ruuviTag.uuid)
                viewModel.alertState.value = alertService.hasRegistrations(for: ruuviTag.uuid) ? .registered : .empty
                return viewModel
            }) ?? []

            // if no tags, open discover
            if viewModels.count == 0 {
                router.openDiscover(output: self)
            } else {
                scrollToCurrentTag()
            }
        }
    }

    private func restartObservingData() {
        ruuviTagDataTokens.forEach({ $0.invalidate() })
        ruuviTagDataTokens.removeAll()
        ruuviTags?.forEach({ (ruuviTag) in
            ruuviTagDataTokens.append(ruuviTag.data.observe { [weak self] (change) in
                switch change {
                case .update:
                    // sync every 1 second
                    if let last = self?.lastSyncViewModelDate {
                        let elapsed = Int(Date().timeIntervalSince(last))
                        if elapsed > 60 {
                            self?.syncViewModels()
                            self?.lastSyncViewModelDate = Date()
                        }
                    }
                case .error(let error):
                    self?.errorPresenter.present(error: error)
                default:
                    break
                }
            })
        })
    }

    private func startObservingRuuviTags() {
        ruuviTags = realmContext.main.objects(RuuviTagRealm.self)
            .filter("isConnectable == true")
        ruuviTagsToken?.invalidate()
        ruuviTagsToken = ruuviTags?.observe { [weak self] (change) in
            switch change {
            case .initial(let ruuviTags):
                self?.restartObservingData()
                if let uuid = self?.tagUUID {
                    self?.configure(uuid: uuid)
                } else if let uuid = ruuviTags.first?.uuid {
                    self?.configure(uuid: uuid)
                }
            case .update(let ruuviTags, _, let insertions, _):
                self?.ruuviTags = ruuviTags
                if let ii = insertions.last {
                    let uuid = ruuviTags[ii].uuid
                    if let index = self?.viewModels.firstIndex(where: { $0.uuid.value == uuid }) {
                        self?.view.scroll(to: index)
                    }
                }
                self?.restartObservingData()
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        }
    }

    private func startListeningToSettings() {
        temperatureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .TemperatureUnitDidChange,
                         object: nil,
                         queue: .main) { [weak self] _ in
            self?.viewModels.forEach({ $0.temperatureUnit.value = self?.settings.temperatureUnit })
        }
        humidityUnitToken = NotificationCenter
            .default
            .addObserver(forName: .HumidityUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
            self?.viewModels.forEach({ $0.humidityUnit.value = self?.settings.humidityUnit })
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
                let viewModel = self?.view.viewModels.first(where: { $0.uuid.value == uuid }) {
                    viewModel.background.value = self?.backgroundPersistence.background(for: uuid)
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
                let uuid = userInfo[AlertServiceAlertDidChangeKey.uuid] as? String {
                sSelf.viewModels.filter({ $0.uuid.value == uuid }).forEach({ (viewModel) in
                    viewModel.alertState.value = sSelf.alertService.hasRegistrations(for: uuid) ? .registered : .empty
                })
            }
        })
    }

    private func startListeningToAlertStatus() {
        ruuviTags?.forEach({ alertService.subscribe(self, to: $0.uuid) })
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
                let viewModel = self?.viewModels.first(where: { $0.uuid.value == uuid }) {
                viewModel.isConnected.value = true
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
                let viewModel = self?.viewModels.first(where: { $0.uuid.value == uuid }) {
                viewModel.isConnected.value = false
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
            if let uuid = notification.userInfo?[LNMDidReceiveKey.uuid] as? String {
                if let index = self?.viewModels.firstIndex(where: { $0.uuid.value == uuid }) {
                    self?.view.scroll(to: index)
                } else {
                    self?.dismiss()
                }
            }
        })
    }
}
// swiftlint:enable file_length
