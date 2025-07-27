import Foundation
import RuuviOntology

class NewCardsBasePresenter: NSObject {

    weak var view: NewCardsBaseViewInput?
    var router: CardsRouterInput?

    // MARK: Child presenter references
    private weak var measurementPresenter: CardsMeasurementPresenterInput?
    private weak var graphPresenter: CardsGraphPresenterInput?
    private weak var alertsPresenter: CardsAlertsPresenterInput?
    private weak var settingsPresenter: CardsSettingsPresenterInput?

    // MARK: Dependencies
    private let ruuviCloudService: RuuviCloudService

    // MARK: Properties
    private var snapshot: RuuviTagCardSnapshot!
    private var snapshots: [RuuviTagCardSnapshot] = []
    private var ruuviTagSensors: [AnyRuuviTagSensor] = []
    private var sensorSettings: [SensorSettings] = []
    private var activeMenu: CardsMenuType = .measurement

    init(
        measurementPresenter: NewCardsMeasurementPresenter,
        graphPresenter: NewCardsGraphPresenter,
        alertsPresenter: NewCardsAlertsPresenter,
        settingsPresenter: NewCardsSettingsPresenter,
        ruuviCloudService: RuuviCloudService
    ) {
        self.measurementPresenter = measurementPresenter
        self.graphPresenter = graphPresenter
        self.alertsPresenter = alertsPresenter
        self.settingsPresenter = settingsPresenter

        self.ruuviCloudService = ruuviCloudService
        super.init()

        self.startServices()
        self.measurementPresenter?.configure(output: self)
    }
}

// MARK: CardsBasePresenterInput
extension NewCardsBasePresenter: CardsBasePresenterInput {
    func configure(
        for snapshot: RuuviTagCardSnapshot,
        snapshots: [RuuviTagCardSnapshot],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        activeMenu: CardsMenuType
    ) {
        self.snapshot = snapshot
        self.snapshots = snapshots
        self.ruuviTagSensors = ruuviTagSensors
        self.sensorSettings = sensorSettings
        self.activeMenu = activeMenu

        // Configure all presenter with active snapshot and associated sensor
        syncPresenters()
    }
}

// MARK: NewCardsBaseViewOutput
extension NewCardsBasePresenter: NewCardsBaseViewOutput {
    func viewWillAppear() {
        view?.setActiveTab(activeMenu)
        view?.setSnapshots(snapshots)
        view?.setActiveSnapshotIndex(currentSnapshotIndex())

        measurementPresenter?
            .configure(
                with: snapshots,
                snapshot: snapshot,
                sensor: currentSensor()
            )

        graphPresenter?
            .configure(
                with: snapshots,
                snapshot: snapshot,
                sensor: currentSensor()
            )
        graphPresenter?.configure(sensorSettings: currentSensorSettings())
    }

    func viewDidChangeTab(_ tab: CardsMenuType) {
        if tab == .measurement || tab == .graph {
            activeMenu = tab
            if tab == .graph {
                graphPresenter?.start()
            }
        } else {
            if let sensor = ruuviTagSensors.first(where: {
                $0.id == snapshot.id
            }) {
                let settings = sensorSettings.first(where: {
                    $0.luid?.value == sensor.luid?.value ||
                    $0.macId?.value == sensor.macId?.value
                })
                router?.openTagSettings(
                    ruuviTag: sensor,
                    latestMeasurement: snapshot.latestRawRecord,
                    sensorSettings: settings,
                    output: self
                )
            }
        }
    }

    func viewDidNavigateToSnapshot(at index: Int) {
        guard index >= 0 && index < snapshots.count && index != currentSnapshotIndex() else {
            return
        }
        self.snapshot = snapshots[index]

        // Configure all presenter with active snapshot and associated sensor
        syncPresenters()

        // Update main view
        view?.setActiveSnapshotIndex(index)

        // Update active menu page
        switch activeMenu {
        case .measurement:
            measurementPresenter?.scroll(to: currentSnapshotIndex(), animated: true)
        case .graph:
            graphPresenter?.scroll(to: currentSnapshotIndex(), animated: true)
        case .alerts, .settings:
            break // TODO: Implement
        }
    }
}

// MARK: CardsMeasurementPresenterOutput
extension NewCardsBasePresenter: CardsMeasurementPresenterOutput {
    func measurementPresenter(
        _ presenter: NewCardsMeasurementPresenter,
        didNavigateToIndex index: Int
    ) {
        viewDidNavigateToSnapshot(at: index)
    }
}

// MARK: TagSettingsModuleOutput
extension NewCardsBasePresenter: TagSettingsModuleOutput {
    func tagSettingsDidDeleteTag(
        module: TagSettingsModuleInput,
        ruuviTag: RuuviTagSensor
    ) {
        //
    }

    func tagSettingsDidDismiss(module: any TagSettingsModuleInput) {
        module.dismiss(completion: nil)
    }
}

extension NewCardsBasePresenter: RuuviCloudServiceDelegate {
    func ruuviCloudService(
        _ service: RuuviCloudService,
        userDidLogin loggedIn: Bool
    ) {
        //
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        userDidLogOut loggedOut: Bool
    ) {
        //
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        syncStatusDidChange isRefreshing: Bool
    ) {
        view?.setActivityIndicatorVisible(isRefreshing)
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        syncDidComplete: Bool
    ) {
        //
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        historySyncInProgress inProgress: Bool,
        for macId: String
    ) {
        if activeMenu == .graph,
            snapshot.identifierData.mac?.value == macId {
            view?.setActivityIndicatorVisible(inProgress)
        }
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        authorizationFailed: Bool
    ) {
        //
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        cloudModeDidChange isEnabled: Bool
    ) {
        //
    }


}

// MARK: Private Helpers
private extension NewCardsBasePresenter {
    func startServices() {
        ruuviCloudService.startObserving()
        ruuviCloudService.delegate = self
    }

    func stopServices() {
        ruuviCloudService.stopObserving()
    }

    func syncPresenters() {
        measurementPresenter?
            .configure(
                with: snapshot,
                sensor: currentSensor()
            )
        graphPresenter?
            .configure(
                with: snapshot,
                sensor: currentSensor()
            )
        alertsPresenter?
            .configure(
                with: snapshot,
                sensor: currentSensor()
            )
        settingsPresenter?
            .configure(
                with: snapshot,
                sensor: currentSensor()
            )
    }

    func currentSensor() -> AnyRuuviTagSensor? {
        return ruuviTagSensors.first(where: {
            $0.id == snapshot.id
        })
    }

    func currentSnapshotIndex() -> Int {
        return snapshots.firstIndex(of: snapshot) ?? 0
    }

    func currentSensorSettings() -> SensorSettings? {
        return sensorSettings.first(where: {
            $0.luid?.value == snapshot.identifierData.luid?.value ||
            $0.macId?.value == snapshot.identifierData.mac?.value
        })
    }
}
