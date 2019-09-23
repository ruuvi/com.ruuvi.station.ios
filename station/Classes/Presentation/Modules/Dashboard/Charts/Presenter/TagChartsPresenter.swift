import Foundation
import RealmSwift

class TagChartsPresenter: TagChartsModuleInput {
    weak var view: TagChartsViewInput!
    var router: TagChartsRouterInput!
    var realmContext: RealmContext!
    var errorPresenter: ErrorPresenter!
    var backgroundPersistence: BackgroundPersistence!
    var settings: Settings!
    
    private var output: TagChartsModuleOutput?
    private var ruuviTagsToken: NotificationToken?
    private var webTagsToken: NotificationToken?
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
    
    deinit {
        ruuviTagsToken?.invalidate()
        webTagsToken?.invalidate()
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
    
    func viewDidTriggerDashboard() {
        router.dismiss()
    }
    
    func viewDidScroll(to index: Int) {
        if viewModels.count > index, let uuid = viewModels[index].uuid.value {
            output?.tagCharts(module: self, didScrollTo: uuid)
        }
    }
}

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
            
            if let index = viewModels.firstIndex(where: { $0.uuid.value == initialUUID }) {
                view.scroll(to: index, immediately: true)
                initialUUID = nil
            }
        }
    }
    
    func restartScanning() {
//        startScanningRuuviTags()
//        startScanningWebTags()
    }
    
    private func startObservingRuuviTags() {
        ruuviTags = realmContext.main.objects(RuuviTagRealm.self)
        ruuviTagsToken = ruuviTags?.observe { [weak self] (change) in
            switch change {
            case .initial:
                self?.restartScanning()
            case .update(let ruuviTags, _, let insertions, _):
                self?.ruuviTags = ruuviTags
                if let ii = insertions.last {
                    let uuid = ruuviTags[ii].uuid
                    if let index = self?.viewModels.firstIndex(where: { $0.uuid.value == uuid }) {
                        self?.view.scroll(to: index)
                    }
                }
                self?.restartScanning()
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
                self?.restartScanning()
            case .update(let webTags, _, let insertions, _):
                self?.webTags = webTags
                if let ii = insertions.last {
                    let uuid = webTags[ii].uuid
                    if let index = self?.viewModels.firstIndex(where: { $0.uuid.value == uuid }) {
                        self?.view.scroll(to: index)
                    }
                }
                self?.restartScanning()
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
    
}
