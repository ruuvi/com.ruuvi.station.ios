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
        settingsPresenter: NewCardsSettingsPresenter
    ) {
        super.init()
        self.measurementPresenter = measurementPresenter
        self.graphPresenter = graphPresenter
        self.alertsPresenter = alertsPresenter
        self.settingsPresenter = settingsPresenter
    }
}

// MARK: CardsBasePresenterInput
extension NewCardsBasePresenter: CardsBasePresenterInput {
    func configure(
        for snapshot: RuuviTagCardSnapshot,
        snapshots: [RuuviTagCardSnapshot],
        ruuviTagSensors: [RuuviOntology.AnyRuuviTagSensor],
        sensorSettings: [any RuuviOntology.SensorSettings],
        activeMenu: CardsMenuType
    ) {
        self.snapshot = snapshot
        self.snapshots = snapshots
        self.ruuviTagSensors = ruuviTagSensors
        self.sensorSettings = sensorSettings
        self.activeMenu = activeMenu
    }
}

// MARK: NewCardsBaseViewOutput
extension NewCardsBasePresenter: NewCardsBaseViewOutput {
    func viewDidChangeTab(_ tab: CardsMenuType) {
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

    func viewDidNavigateTo(_ snapshot: RuuviTagCardSnapshot) {}
}

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
