import Foundation
import RealmSwift
import BTKit

class DashboardPresenter: DashboardModuleInput {
    weak var view: DashboardViewInput!
    var router: DashboardRouterInput!
    var realmContext: RealmContext!
    var errorPresenter: ErrorPresenter!
    var settings: Settings!
    var backgroundPersistence: BackgroundPersistence!
    
    private let scanner = Ruuvi.scanner
    private var ruuviTagsToken: NotificationToken?
    private var observeTokens = [ObservationToken]()
    private var settingsToken: NSObjectProtocol?
    private var backgroundToken: NSObjectProtocol?
    private var stateToken: ObservationToken?
    private var ruuviTags: Results<RuuviTagRealm>? {
        didSet {
            viewModels = ruuviTags?.compactMap({ (ruuviTag) -> DashboardRuuviTagViewModel in
                let viewModel = DashboardRuuviTagViewModel(ruuviTag)
                viewModel.temperatureUnit.value = settings.temperatureUnit
                viewModel.background.value = backgroundPersistence.background(for: ruuviTag.uuid)
                return viewModel
            }) ?? []
            openDiscoverIfEmpty()
        }
    }
    private var viewModels = [DashboardRuuviTagViewModel]() {
        didSet {
            view.viewModels = viewModels
        }
    }
    
    deinit {
        ruuviTagsToken?.invalidate()
        observeTokens.forEach( { $0.invalidate() } )
        stateToken?.invalidate()
        if let settingsToken = settingsToken {
            NotificationCenter.default.removeObserver(settingsToken)
        }
        if let backgroundToken = backgroundToken {
            NotificationCenter.default.removeObserver(backgroundToken)
        }
    }
}

extension DashboardPresenter: DashboardViewOutput {
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
    
    func viewDidAppear() {
        openDiscoverIfEmpty()
    }
    
    func viewDidTriggerMenu() {
        router.openMenu(output: self)
    }
    
    func viewDidTriggerSettings(for viewModel: DashboardRuuviTagViewModel) {
        if let ruuviTag = ruuviTags?.first(where: { $0.uuid == viewModel.uuid.value}) {
            router.openTagSettings(ruuviTag: ruuviTag, humidity: viewModel.humidity.value)
        }
    }
    
    func viewDidTapOnRSSI(for viewModel: DashboardRuuviTagViewModel) {
//        if let ruuviTag = ruuviTags?.first(where: { $0.uuid == viewModel.uuid.value}) {
//            router.openChart(ruuviTag: ruuviTag, type: .rssi)
//        }
    }
}

// MARK: - MenuModuleOutput
extension DashboardPresenter: MenuModuleOutput {
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
extension DashboardPresenter {
    private func openDiscoverIfEmpty() {
        if view.viewModels.count == 0 {
            router.openDiscover()
        }
    }
    
    private func startObservingBluetoothState() {
        stateToken = scanner.state(self, closure: { (observer, state) in
            if state != .poweredOn {
                observer.view.showBluetoothDisabled()
            }
        })
    }
    
    private func stopObservingBluetoothState() {
        stateToken?.invalidate()
    }
    
    
    private func startListeningToSettings() {
        settingsToken = NotificationCenter.default.addObserver(forName: .TemperatureUnitDidChange, object: nil, queue: .main) { [weak self] (notification) in
            self?.viewModels.forEach( { $0.temperatureUnit.value = self?.settings.temperatureUnit} )
        }
    }
    
    private func startScanningRuuviTags() {
        observeTokens.forEach( { $0.invalidate() } )
        observeTokens.removeAll()
        for viewModel in view.viewModels {
            if let uuid = viewModel.uuid.value {
                observeTokens.append(scanner.observe(self, uuid: uuid) { [weak self] (observer, device) in
                    if let ruuviTag = device.ruuvi?.tag,
                        let viewModel = self?.viewModels.first(where: { $0.uuid.value == ruuviTag.uuid }) {
                        viewModel.update(with: ruuviTag)
                    }
                })
            }
        }
    }
    
    private func startObservingRuuviTags() {
        ruuviTags = realmContext.main.objects(RuuviTagRealm.self)
        ruuviTagsToken = ruuviTags?.observe { [weak self] (change) in
            switch change {
            case .initial(let ruuviTags):
                self?.ruuviTags = ruuviTags
                self?.startScanningRuuviTags()
            case .update(let ruuviTags, _, let insertions, _):
                self?.ruuviTags = ruuviTags
                if let index = insertions.last {
                    self?.view.scroll(to: index)
                }
                self?.startScanningRuuviTags()
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        }
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
