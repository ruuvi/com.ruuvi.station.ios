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
    var ruuviTagPersistence: RuuviTagPersistence!
    var calibrationService: CalibrationService!
    
    private let scanner = Ruuvi.scanner
    private var ruuviTagsToken: NotificationToken?
    private var observeTokens = [ObservationToken]()
    private var settingsToken: NSObjectProtocol?
    private var stateToken: ObservationToken?
    private var ruuviTags: Results<RuuviTagRealm>? {
        didSet {
            if let ruuviTags = ruuviTags {
                view.viewModels = ruuviTags.map( {
                    let last = lastValues[$0.uuid]
                    return DashboardRuuviTagViewModel(uuid: $0.uuid, name: $0.name, celsius: last?.celsius ?? 0, humidity: last?.humidity ?? 0, pressure: last?.pressure ?? 0, rssi: last?.rssi ?? 0, version: $0.version, voltage: last?.voltage, background: backgroundPersistence.background(for: $0.uuid), mac: $0.mac, humidityOffset: $0.humidityOffset, humidityOffsetDate: $0.humidityOffsetDate)
                } )
            } else {
                view.viewModels = []
            }
            openDiscoverIfEmpty()
        }
    }
    private var lastValues: [String:RuuviTag] = [String:RuuviTag]()
    
    deinit {
        ruuviTagsToken?.invalidate()
        observeTokens.forEach( { $0.invalidate() } )
        stateToken?.invalidate()
        if let settingsToken = settingsToken {
            NotificationCenter.default.removeObserver(settingsToken)
        }
    }
}

extension DashboardPresenter: DashboardViewOutput {
    func viewDidLoad() {
        view.temperatureUnit = settings.temperatureUnit
        startObservingRuuviTags()
        startListeningToSettings()
    }
    
    func viewWillAppear() {
        startScanningRuuviTags()
        startObservingBluetoothState()
    }
    
    func viewWillDisappear() {
        stopScanningRuuviTags()
        stopObservingBluetoothState()
    }
    
    func viewDidAppear() {
        openDiscoverIfEmpty()
    }
    
    func viewDidTriggerMenu() {
        router.openMenu(output: self)
    }
    
    func viewDidTriggerSettings(for viewModel: DashboardRuuviTagViewModel) {
        view.showMenu(for: viewModel)
    }
    
    func viewDidAskToRemove(viewModel: DashboardRuuviTagViewModel) {
        if let ruuviTag = ruuviTags?.first(where: { $0.uuid == viewModel.uuid}) {
            let operation = ruuviTagPersistence.delete(ruuviTag: ruuviTag)
            operation.on(failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            })
        }
    }
    
    func viewDidAskToRename(viewModel: DashboardRuuviTagViewModel) {
        view.showRenameDialog(for: viewModel)
    }
    
    func viewDidChangeName(of viewModel: DashboardRuuviTagViewModel, to name: String) {
        if let ruuviTag = ruuviTags?.first(where: { $0.uuid == viewModel.uuid}) {
            let operation = ruuviTagPersistence.update(name: name, of: ruuviTag)
            operation.on(failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            })
        }
    }
    
    func viewDidTapOnRSSI(for viewModel: DashboardRuuviTagViewModel) {
//        if let ruuviTag = ruuviTags?.first(where: { $0.uuid == viewModel.uuid}) {
//            router.openChart(ruuviTag: ruuviTag, type: .rssi)
//        }   
    }
    
    func viewDidAskToCalibrateHumidity(viewModel: DashboardRuuviTagViewModel) {
        if let ruuviTag = ruuviTags?.first(where: { $0.uuid == viewModel.uuid}) {
            let update = calibrationService.calibrateHumiditySaltTest(currentValue: viewModel.humidity, for: ruuviTag)
            update.on(failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            })
        }
    }
    
    func viewDidAskToClearHumidityCalibration(viewModel: DashboardRuuviTagViewModel) {
        if let ruuviTag = ruuviTags?.first(where: { $0.uuid == viewModel.uuid}) {
            let clear = calibrationService.cleanHumidityCalibration(for: ruuviTag)
            clear.on(failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            })
        }
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
            guard let sSelf = self else { return }
            sSelf.view.temperatureUnit = sSelf.settings.temperatureUnit
        }
    }
    
    private func startScanningRuuviTags() {
        observeTokens.forEach( { $0.invalidate() } )
        observeTokens.removeAll()
        for viewModel in view.viewModels {
            observeTokens.append(scanner.observe(self, uuid: viewModel.uuid) { [weak self] (observer, device) in
                if let tagData = device.ruuvi?.tag {
                    let model = DashboardRuuviTagViewModel(uuid: viewModel.uuid, name: viewModel.name, celsius: tagData.celsius, humidity: tagData.humidity, pressure: tagData.pressure, rssi: tagData.rssi, version: tagData.version, voltage: tagData.voltage, background: viewModel.background, mac: viewModel.mac, humidityOffset: viewModel.humidityOffset, humidityOffsetDate: viewModel.humidityOffsetDate)
                    observer.view.reload(viewModel: model)
                    self?.lastValues[tagData.uuid] = tagData
                }
            })
        }
    }
    
    private func stopScanningRuuviTags() {
        observeTokens.forEach( { $0.invalidate() } )
        observeTokens.removeAll()
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
}
