import Foundation
import RealmSwift
import BTKit

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
    weak var tagActions: TagActionsModuleInput?
    
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
    private var webTagsToken: NotificationToken?
    private var stateToken: ObservationToken?
    private var ruuviTagDataTokens = [NotificationToken]()
    private var webTagDataTokens = [NotificationToken]()
    private var temperatureUnitToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
    private var backgroundToken: NSObjectProtocol?
    private var initialUUID: String?
    private var ruuviTags: Results<RuuviTagRealm>? {
        didSet {
            syncViewModels()
        }
    }
    private var webTags: Results<WebTagRealm>? {
        didSet {
            syncViewModels()
        }
    }
    private var viewModels = [TagChartsViewModel]() {
        didSet {
            view.viewModels = viewModels
        }
    }
    private var tagUUID: String! {
        didSet {
            output?.tagCharts(module: self, didScrollTo: tagUUID)
            tagActions?.configure(uuid: tagUUID)
            tagActions?.configure(isConnectable: tagIsConnectable)
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
        webTagsToken?.invalidate()
        stateToken?.invalidate()
        ruuviTagDataTokens.forEach({ $0.invalidate() })
        webTagDataTokens.forEach({ $0.invalidate() })
        if let settingsToken = temperatureUnitToken {
            NotificationCenter.default.removeObserver(settingsToken)
        }
        if let humidityUnitToken = humidityUnitToken {
            NotificationCenter.default.removeObserver(humidityUnitToken)
        }
        if let backgroundToken = backgroundToken {
            NotificationCenter.default.removeObserver(backgroundToken)
        }
    }
    
    func configure(uuid: String, output: TagChartsModuleOutput) {
        self.initialUUID = uuid
        self.output = output
    }
}

extension TagChartsPresenter: TagChartsViewOutput {
    
    func viewDidLoad() {
        startObservingRuuviTags()
        startObservingWebTags()
        startListeningToSettings()
        startObservingBackgroundChanges()
    }
    
    func viewWillAppear() {
        startObservingBluetoothState()
    }
    
    func viewWillDisappear() {
        stopObservingBluetoothState()
    }
    
    func viewDidTriggerMenu() {
        router.openMenu(output: self)
    }
    
    func viewDidTriggerDashboard(for viewModel: TagChartsViewModel) {
        router.dismiss()
    }
    
    func viewDidTriggerSettings(for viewModel: TagChartsViewModel) {
        if viewModel.type == .ruuvi, let ruuviTag = ruuviTags?.first(where: { $0.uuid == viewModel.uuid.value }) {
            router.openTagSettings(ruuviTag: ruuviTag, humidity: viewModel.relativeHumidity.value?.last?.value)
        } else if viewModel.type == .web, let webTag = webTags?.first(where: { $0.uuid == viewModel.uuid.value }) {
            router.openWebTagSettings(webTag: webTag)
        }
    }
    
    func viewDidScroll(to viewModel: TagChartsViewModel) {
        if let uuid = viewModel.uuid.value {
            tagUUID = uuid
        } else {
            assert(false)
        }
    }
}

// MARK: - MenuModuleOutput
extension TagChartsPresenter: MenuModuleOutput {
    func menu(module: MenuModuleInput, didSelectAddRuuviTag sender: Any?) {
        module.dismiss()
        router.openDiscover()
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
}

// MARK: - Private
extension TagChartsPresenter {
    private func syncViewModels() {
        if ruuviTags != nil && webTags != nil {
            let ruuviViewModels = ruuviTags?.compactMap({ (ruuviTag) -> TagChartsViewModel in
                let viewModel = TagChartsViewModel(ruuviTag)
                viewModel.background.value = backgroundPersistence.background(for: ruuviTag.uuid)
                viewModel.temperatureUnit.value = settings.temperatureUnit
                viewModel.humidityUnit.value = settings.humidityUnit
                return viewModel
            }) ?? []
            let webViewModels = webTags?.compactMap({ (webTag) -> TagChartsViewModel in
                let viewModel = TagChartsViewModel(webTag)
                viewModel.background.value = backgroundPersistence.background(for: webTag.uuid)
                viewModel.temperatureUnit.value = settings.temperatureUnit
                viewModel.humidityUnit.value = settings.humidityUnit
                return viewModel
            }) ?? []
            viewModels = ruuviViewModels + webViewModels
            
            // if no tags, open discover
            if viewModels.count == 0 {
                router.openDiscover()
            }
            
            if let initialUUID = initialUUID {
                tagUUID = initialUUID
            }
            
            if let index = viewModels.firstIndex(where: { $0.uuid.value == initialUUID }) {
                view.scroll(to: index, immediately: true)
                initialUUID = nil
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
                    self?.syncViewModels()
                case .error(let error):
                    self?.errorPresenter.present(error: error)
                default:
                    break
                }
            })
        })
        
        webTagDataTokens.forEach({ $0.invalidate() })
        webTagDataTokens.removeAll()
        webTags?.forEach({ (webTag) in
            webTagDataTokens.append(webTag.data.observe({ [weak self] (change) in
                switch change {
                case .update:
                    self?.syncViewModels()
                case .error(let error):
                    self?.errorPresenter.present(error: error)
                default:
                    break
                }
            }))
        })
    }
    
    private func startObservingRuuviTags() {
        ruuviTags = realmContext.main.objects(RuuviTagRealm.self)
        ruuviTagsToken?.invalidate()
        ruuviTagsToken = ruuviTags?.observe { [weak self] (change) in
            switch change {
            case .initial:
                self?.restartObservingData()
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
    
    private func startObservingWebTags() {
        webTags = realmContext.main.objects(WebTagRealm.self)
        webTagsToken = webTags?.observe({ [weak self] (change) in
            switch change {
            case .initial:
                self?.restartObservingData()
            case .update(let webTags, _, let insertions, _):
                self?.webTags = webTags
                if let ii = insertions.last {
                    let uuid = webTags[ii].uuid
                    if let index = self?.viewModels.firstIndex(where: { $0.uuid.value == uuid }) {
                        self?.view.scroll(to: index)
                    }
                }
                self?.restartObservingData()
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        })
    }
    
    private func startListeningToSettings() {
        temperatureUnitToken = NotificationCenter.default.addObserver(forName: .TemperatureUnitDidChange, object: nil, queue: .main) { [weak self] (notification) in
            self?.viewModels.forEach( { $0.temperatureUnit.value = self?.settings.temperatureUnit } )
        }
        humidityUnitToken = NotificationCenter.default.addObserver(forName: .HumidityUnitDidChange, object: nil, queue: .main, using: { [weak self] (notification) in
            self?.viewModels.forEach( { $0.humidityUnit.value = self?.settings.humidityUnit } )
        })
    }
    
    private func startObservingBackgroundChanges() {
        backgroundToken = NotificationCenter.default.addObserver(forName: .BackgroundPersistenceDidChangeBackground, object: nil, queue: .main) { [weak self] notification in
            if let userInfo = notification.userInfo, let uuid = userInfo[BackgroundPersistenceDidChangeBackgroundKey.uuid] as? String {
                if let viewModel = self?.view.viewModels.first(where: { $0.uuid.value == uuid }) {
                    viewModel.background.value = self?.backgroundPersistence.background(for: uuid)
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
}
