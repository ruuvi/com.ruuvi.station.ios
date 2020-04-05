// swiftlint:disable file_length
import Foundation
import RealmSwift
import BTKit
import UIKit
import Charts

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

    private var isSyncing: Bool = false
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
    private var ruuviTagDataToken: NotificationToken?
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
    private var isInUpdate = false
    private var ruuviTagData: [RuuviMeasurement] = []
    private var ruuviTags: Results<RuuviTagRealm>? {
        didSet {
            syncViewModels()
            startListeningToAlertStatus()
        }
    }
    private var currentViewModel: TagChartsViewModel? {
        return viewModels.first(where: {$0.uuid.value == tagUUID})
    }
    private var viewModels = [TagChartsViewModel]() {
        didSet {
            DispatchQueue.main.async {
                self.isLoading = false
                self.view.viewModels = self.viewModels
            }
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
        isLoading = true
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
        if viewModel.type == .ruuvi, let ruuviTag = ruuviTags?.first(where: { $0.uuid == viewModel.uuid.value }) {
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
        if let uuid = viewModel.uuid.value {
            isSyncing = true
            let connectionTimeout: TimeInterval = settings.connectionTimeout
            let serviceTimeout: TimeInterval = settings.serviceTimeout
            let op = gattService.syncLogs(with: uuid, progress: { [weak self] progress in
                DispatchQueue.main.async { [weak self] in
                    self?.view.setSync(progress: progress, for: viewModel)
                }
            }, connectionTimeout: connectionTimeout, serviceTimeout: serviceTimeout)
            op.on(success: { [weak self] _ in
                self?.view.setSync(progress: nil, for: viewModel)
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
        if let uuid = viewModel.uuid.value {
            isLoading = true
            let op = ruuviTagService.clearHistory(uuid: uuid)
            op.on(failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
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
        guard let ruuviTags = ruuviTags else {
            return
        }
        viewModels = ruuviTags.compactMap({ (ruuviTag) -> TagChartsViewModel in
            let viewModel = TagChartsViewModel(ruuviTag)
            viewModel.background.value = backgroundPersistence.background(for: ruuviTag.uuid)
            viewModel.isConnected.value = background.isConnected(uuid: ruuviTag.uuid)
            viewModel.alertState.value = alertService
                .hasRegistrations(for: ruuviTag.uuid) ? .registered : .empty
            viewModel.temperatureUnit.value = settings.temperatureUnit
            viewModel.humidityUnit.value = settings.humidityUnit
            viewModel.temperatureChartData.value = LineChartData(dataSet: TagChartsPresenter.newDataSet())
            viewModel.humidityChartData.value = LineChartData(dataSet: TagChartsPresenter.newDataSet())
            viewModel.pressureChartData.value = LineChartData(dataSet: TagChartsPresenter.newDataSet())
            return viewModel
        })
        // if no tags, open discover
        if viewModels.count == 0 {
            router.openDiscover(output: self)
        } else {
            scrollToCurrentTag()
            restartObservingData()
        }
    }
    // swiftlint:disable all
    private func restartObservingData() {
        ruuviTagDataToken?.invalidate()
        self.isLoading = true
        guard let uuid = tagUUID else {
            return
        }
        let ruuviTagDataRealm = realmContext.main.objects(RuuviTagDataRealm.self)
            .filter("ruuviTag.uuid == %@", uuid)
        ruuviTagDataToken = ruuviTagDataRealm.observe {
            [weak self] (change) in
            switch change {
            case .initial(let results):
                self?.isInUpdate = true
                guard let viewModel = self?.viewModels.first(where: {$0.uuid.value == self?.tagUUID}) else {
                    return
                }
                autoreleasepool {
                    var newValues = [RuuviMeasurement]()
                    if let first = results.first {
                        self?.lastChartSyncDate = first.date
                        newValues.append(first.measurement)
                    }
                    for result in results {
                        if let last = self?.lastChartSyncDate,
                            let chartIntervalSeconds = self?.settings.chartIntervalSeconds {
                            let elapsed = Int(result.measurement.date.timeIntervalSince(last))
                            if elapsed >= chartIntervalSeconds {
                                self?.lastChartSyncDate = result.measurement.date
                                newValues.append(result.measurement)
                            }
                        } else {
                            self?.lastChartSyncDate = result.measurement.date
                            newValues.append(result.measurement)
                        }
                    }
                    if let last = results.last,
                        last.date != newValues.last?.date {
                        self?.lastChartSyncDate = last.date
                        newValues.append(last.measurement)
                    }
                    newValues.sort(by: { $0.date < $1.date })
                    self?.ruuviTagData = newValues
                    self?.createChartData(for: viewModel)
                    self?.isLoading = false
                }
            case .update(let results, _, let insertions, _):
                // sync every 1 second
                self?.isSyncing = false
                insertions.forEach({ i in
                    let newValue = results[i].measurement
                    self?.ruuviTagData.append(newValue)
                    if let viewModel = self?.viewModels.first(where: {$0.uuid.value == newValue.tagUuid}),
                        self?.view.viewIsVisible == true {
                        if let last = self?.lastChartSyncDate,
                            let chartIntervalSeconds = self?.settings.chartIntervalSeconds {
                            let elapsed = Int(newValue.date.timeIntervalSince(last))
                            if elapsed >= chartIntervalSeconds {
                                self?.lastChartSyncDate = newValue.date
                                self?.insertMeasurements([newValue], into: viewModel)
                            }
                        } else {
                            self?.lastChartSyncDate = newValue.date
                            self?.insertMeasurements([newValue], into: viewModel)
                        }
                    }
                })
            default:
                break
            }
        }
    }
    // swiftlint:enable all

    private func startObservingRuuviTags() {
        ruuviTags = realmContext.main.objects(RuuviTagRealm.self)
            .filter("isConnectable == true")
        ruuviTagsToken?.invalidate()
        ruuviTagsToken = ruuviTags?.observe { [weak self] (change) in
            switch change {
            case .initial(let ruuviTags):
                if let uuid = self?.tagUUID {
                    self?.configure(uuid: uuid)
                } else if let uuid = ruuviTags.first?.uuid {
                    self?.configure(uuid: uuid)
                }
            case .update(let ruuviTags, _, let insertions, _):
                guard self?.view.viewIsVisible == true else {
                    return
                }
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

    private func stopObservingRuuviTagsData() {
        ruuviTagDataToken?.invalidate()
    }

    private func startListeningToSettings() {
        temperatureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .TemperatureUnitDidChange,
                         object: nil,
                         queue: .main) { [weak self] _ in
            self?.viewModels.forEach({ $0.temperatureUnit.value = self?.settings.temperatureUnit })
            self?.restartObservingData()
        }
        humidityUnitToken = NotificationCenter
            .default
            .addObserver(forName: .HumidityUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
            self?.viewModels.forEach({ $0.humidityUnit.value = self?.settings.humidityUnit })
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
    // MARK: - ChartsDataSet
    private static func newDataSet() -> LineChartDataSet {
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
    private func insertMeasurements(_ newValues: [RuuviMeasurement], into viewModel: TagChartsViewModel) {
        newValues.forEach({
            guard $0.tagUuid == viewModel.uuid.value else {
                return
            }
            viewModel.temperatureChartData.value?.addEntry(getEntry(for: $0, with: .temperature), dataSetIndex: 0)
            viewModel.humidityChartData.value?.addEntry(getEntry(for: $0, with: .humidity), dataSetIndex: 0)
            viewModel.pressureChartData.value?.addEntry(getEntry(for: $0, with: .pressure), dataSetIndex: 0)
        })
        self.drawCirclesIfNeeded(for: viewModel.temperatureChartData.value)
        self.drawCirclesIfNeeded(for: viewModel.humidityChartData.value)
        self.drawCirclesIfNeeded(for: viewModel.pressureChartData.value)
        viewModel.temperatureChart.value?.reloadData()
        viewModel.humidityChart.value?.reloadData()
        viewModel.pressureChart.value?.reloadData()
    }
    private func drawCirclesIfNeeded(for chartData: LineChartData?) {
        if let dataSet = chartData?.dataSets.first as? LineChartDataSet {
            switch dataSet.entries.count {
            case 1:
                dataSet.circleRadius = 6
                dataSet.drawCirclesEnabled = true
            case 2...threshold:
                dataSet.circleRadius = 2
                dataSet.drawCirclesEnabled = true
            default:
                dataSet.drawCirclesEnabled = false
            }
        }
    }
    private func createChartData(for viewModel: TagChartsViewModel) {
        guard let chartDurationThreshold = Calendar.current.date(byAdding: .hour,
                                               value: -settings.chartDurationHours,
                                               to: Date())?.timeIntervalSince1970 else {
            return
        }
        let currentDate = Date().timeIntervalSince1970
        fetchPointsByDates(for: viewModel, withType: .temperature, start: chartDurationThreshold, stop: currentDate)
        viewModel.temperatureChart.value?.reloadData()
        viewModel.temperatureChart.value?.fitZoomTo(first: chartDurationThreshold, last: currentDate)

        fetchPointsByDates(for: viewModel, withType: .humidity, start: chartDurationThreshold, stop: currentDate)
        viewModel.humidityChart.value?.reloadData()
        viewModel.humidityChart.value?.fitZoomTo(first: chartDurationThreshold, last: currentDate)

        fetchPointsByDates(for: viewModel, withType: .pressure, start: chartDurationThreshold, stop: currentDate)
        viewModel.pressureChart.value?.reloadData()
        viewModel.pressureChart.value?.fitZoomTo(first: chartDurationThreshold, last: currentDate)
    }
    private func bindDataSet(_ dataSet: inout LineChartDataSet, _ entries: [ChartDataEntry]) {
        let firstPoint = dataSet.first
        let lastPoint = dataSet.last
        dataSet.removeAll(keepingCapacity: true)
        if let first = firstPoint {
            _ = dataSet.addEntryOrdered(first)
        }
        entries.forEach({
            _ = dataSet.addEntryOrdered($0)
        })
        if let last = lastPoint {
            _ = dataSet.addEntryOrdered(last)
        }
    }
}
// MARK: - TagChartViewOutput
extension TagChartsPresenter: TagChartViewOutput {
// swiftlint:disable:next cyclomatic_complexity
    private func fetchPointsByDates(for viewModel: TagChartsViewModel,
                                    withType type: MeasurementType,
                                    start: TimeInterval,
                                    stop: TimeInterval) {
        var chartData: LineChartData = LineChartData()
        switch type {
        case .temperature:
            if let data = viewModel.temperatureChartData.value {
                chartData = data
            }
        case .humidity:
            if let data = viewModel.humidityChartData.value {
                chartData = data
            }
        case .pressure:
            if let data = viewModel.pressureChartData.value {
                chartData = data
            }
        default:
            fatalError("\(#function):\(#line) Undeclarated chart type")
        }
        let filtered = ruuviTagData
            .filter({$0.tagUuid == viewModel.uuid.value})
            .sorted(by: {$0.date < $1.date})
        var sorted: [RuuviMeasurement] = []
        if let first = filtered.first {
            sorted.append(first)
        }
        filtered.forEach({
            guard $0.date.timeIntervalSince1970 > start,
                $0.date.timeIntervalSince1970 < stop else {
                return
            }
            sorted.append($0)
        })
        if let last = filtered.last {
            sorted.append(last)
        }
        self.setDownSampled(dataSet: sorted, to: chartData, withType: type)
        switch type {
        case .temperature:
            viewModel.temperatureChart.value?.reloadData()
        case .humidity:
            viewModel.humidityChart.value?.reloadData()
        case .pressure:
            viewModel.pressureChart.value?.reloadData()
        default:
            return
        }
    }
    func didChangeVisibleRange(_ chartView: TagChartView) {
        guard !isInUpdate,
            let uuid = chartView.tagUuid,
            let viewModel = viewModels.first(where: { $0.uuid.value == uuid }) else {
            return
        }
        isInUpdate = true
        fetchPointsByDates(for: viewModel,
                           withType: chartView.chartDataType,
                           start: chartView.lowestVisibleX,
                           stop: chartView.highestVisibleX)
    }
}
extension TagChartsPresenter {
    // swiftlint:disable:next cyclomatic_complexity
    private func getEntry(for tagData: RuuviMeasurement,
                          with type: MeasurementType) -> ChartDataEntry {
        let value: Double?
        switch type {
        case .temperature:
            value = tagData.temperature?.converted(to: settings.temperatureUnit.unitTemperature).value
        case .humidity:
            switch settings.humidityUnit {
            case .dew:
                switch settings.temperatureUnit {
                case .celsius:
                    value = tagData.humidity?.Td
                case .fahrenheit:
                    value = tagData.humidity?.TdF
                case .kelvin:
                    value = tagData.humidity?.TdK
                }
            case .gm3:
                value = tagData.humidity?.ah
            case .percent:
                if let relativeHumidity = tagData.humidity?.rh {
                    value = relativeHumidity * 100
                } else {
                    value = nil
                }
            }
        case .pressure:
            value = tagData.pressure?.converted(to: .hectopascals).value
        default:
            fatalError("before need implement chart with current type!")
        }
        guard let y = value else {
            fatalError("before need implement chart with current type!")
        }
        return ChartDataEntry(x: tagData.date.timeIntervalSince1970, y: y)
    }
    // swiftlint:disable function_body_length
    private func setDownSampled(dataSet: [RuuviMeasurement] = [],
                                to chartData: LineChartData,
                                withType type: MeasurementType) {
        if let chartDataSet = chartData.dataSets.first as? LineChartDataSet {
            chartDataSet.removeAll(keepingCapacity: true)
            chartDataSet.drawCirclesEnabled = false
        } else {
            chartData.addDataSet(TagChartsPresenter.newDataSet())
        }
        let data_length = dataSet.count
        if threshold >= data_length
            || threshold == 0 {
            dataSet.forEach({
                chartData.addEntry(getEntry(for: $0, with: type), dataSetIndex: 0)
            })
            self.drawCirclesIfNeeded(for: chartData)
            isInUpdate = false
            return // Nothing to do
        }
        // Bucket size. Leave room for start and end data points
        let every = (data_length - 2) / (threshold - 2)
        var a = 0  // Initially a is the first point in the triangle
        var max_area_point: (Double, Double) = (0, 0)
        var max_area: Double = 0
        var area: Double = 0
        var next_a: Int = 0
        var avg_x: Double = 0
        var avg_y: Double = 0
        var avg_range_start: Int = 0
        var avg_range_end: Int = 0
        var avg_range_length: Int = 0
        var range_offs: Int = 0
        var range_to: Int = 0
        var point_a_x: Double = 0
        var point_a_y: Double = 0
        let firstPoint = dataSet.first!
        chartData.addEntry(getEntry(for: firstPoint, with: type), dataSetIndex: 0)
        for i in 0..<(threshold - 2) {
            // Calculate point average for next bucket (containing c)
            avg_x = 0
            avg_y = 0
            avg_range_start  = Int( floor( Double( ( i + 1 ) * every) ) + 1)
            avg_range_end    = Int( floor( Double( ( i + 2 ) * every ) ) + 1)
            avg_range_end = avg_range_end < data_length ? avg_range_end : data_length
            avg_range_length = avg_range_end - avg_range_start
            for avg_range_start in avg_range_start..<avg_range_end {
                let point_a = getEntry(for: dataSet[avg_range_start], with: type)
                avg_x += point_a.x
                avg_y += point_a.y
            }
            avg_x /= Double(avg_range_length)
            avg_y /= Double(avg_range_length)
            // Get the range for this bucket
            range_offs = Int(floor( Double((i + 0) * every) ) + 1)
            range_to   = Int(floor( Double((i + 1) * every )) + 1)
            // Point a
            let point_a = getEntry(for: dataSet[ a ], with: type)
            point_a_x = point_a.x
            point_a_y = point_a.y
            max_area = -1
            area = -1
            for range_offs in range_offs..<range_to {
                // Calculate triangle area over three buckets
                let point_offs = getEntry(for: dataSet[range_offs], with: type)
                area = abs( ( point_a_x - avg_x ) * ( point_offs.y  - point_a_y ) -
                    ( point_a_x - point_offs.x ) * ( avg_y - point_a_y )
                )
                area *= 0.5
                if area > max_area {
                    max_area = area
                    max_area_point = (point_offs.x, point_offs.y)
                    next_a = range_offs // Next a is this b
                }
            }
            chartData.addEntry(ChartDataEntry(x: max_area_point.0, y: max_area_point.1), dataSetIndex: 0)
            a = next_a // This a is the next a (chosen b)
        }
        let lastItem = dataSet.last!
        chartData.addEntry(getEntry(for: lastItem, with: type), dataSetIndex: 0)
        chartData.notifyDataChanged()
        isInUpdate = false
    }
    // swiftlint:enable function_body_length
}
// swiftlint:enable file_length
