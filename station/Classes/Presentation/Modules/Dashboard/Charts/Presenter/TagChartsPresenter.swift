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
    private var stateToken: ObservationToken?
    private var ruuviTagDataTokens = [NotificationToken]()
    private var temperatureUnitToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
    private var backgroundToken: NSObjectProtocol?
    private var ruuviTags: Results<RuuviTagRealm>? {
        didSet {
            syncViewModels()
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
                tagActions?.configure(uuid: tagUUID)
                tagActions?.configure(isConnectable: tagIsConnectable)
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
    }
    
    func configure(output: TagChartsModuleOutput) {
        self.output = output
    }
    
    func configure(uuid: String) {
        self.tagUUID = uuid
    }
}

extension TagChartsPresenter: TagChartsViewOutput {
    
    func viewDidLoad() {
        startObservingRuuviTags()
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
                return viewModel
            }) ?? []
            
            // if no tags, open discover
            if viewModels.count == 0 {
                router.openDiscover()
            } else {
                scrollToCurrentTag()
            }
            
            tagActions?.configure(isConnectable: tagIsConnectable)
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
    }
    
    private func startObservingRuuviTags() {
        ruuviTags = realmContext.main.objects(RuuviTagRealm.self)
            .filter("isConnectable == true")
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
