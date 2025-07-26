import UIKit
import RuuviOntology
import RuuviLocal

class CardsCoordinator: RuuviCoordinator {
    private var cardsBaseViewController: NewCardsBaseViewController!
    private var cardsMeasurementViewController: NewCardsMeasurementViewController!
    private var cardsGraphViewController: NewCardsGraphViewController!
    private var cardsAlertsViewController: NewCardsAlertsViewController!
    private var cardsSettingsViewController: NewCardsSettingsViewController!

    private var cardsBaseViewPresenter: NewCardsBasePresenter!
    private var cardsMeasurementViewPresenter: NewCardsMeasurementPresenter!
    private var cardsGraphViewPresenter: NewCardsGraphPresenter!
    private var cardsAlertsViewPresenter: NewCardsAlertsPresenter!
    private var cardsSettingsViewPresenter: NewCardsSettingsPresenter!

    private var cardsRouter: CardsRouter!

    private var snapshot: RuuviTagCardSnapshot!
    private var snapshots: [RuuviTagCardSnapshot] = []
    private var ruuviTagSensors: [AnyRuuviTagSensor] = []
    private var sensorSettings: [SensorSettings] = []
    private var activeMenu: CardsMenuType = .measurement
    private var output: NewCardsModuleOutput!

    private var tabs: [CardsMenuType: UIViewController] = [:]

    init(
        baseViewController: UIViewController,
        for snapshot: RuuviTagCardSnapshot,
        snapshots: [RuuviTagCardSnapshot],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        activeMenu: CardsMenuType,
        output: NewCardsModuleOutput
    ) {
        super.init(baseViewController: baseViewController)
        self.snapshot = snapshot
        self.snapshots = snapshots
        self.ruuviTagSensors = ruuviTagSensors
        self.sensorSettings = sensorSettings
        self.activeMenu = activeMenu
        self.output = output
    }

    override func start() {
        super.start()

        tabs = createTabViewControllers()
        cardsBaseViewController = createBaseViewController()

        baseViewController.navigationController?.pushViewController(
            cardsBaseViewController,
            animated: true
        )
    }

    override func stop() {
        super.stop()
        // TODO: Cleanup
    }
}

// MARK: Helpers
private extension CardsCoordinator {
    func createTabViewControllers() -> [CardsMenuType: UIViewController] {
        cardsMeasurementViewController = createMeasurementViewController()
        cardsGraphViewController = createGraphViewController()
        cardsAlertsViewController = createAlertsViewController()
        cardsSettingsViewController = createSettingsViewController()

        return [
            .measurement: cardsMeasurementViewController,
            .graph: cardsGraphViewController,
            .alerts: cardsAlertsViewController,
            .settings: cardsSettingsViewController,
        ]
    }
}

// MARK: Base
private extension CardsCoordinator {
    func createBaseViewController() -> NewCardsBaseViewController {
        let r = AppAssembly.shared.assembler.resolver

        let viewController = NewCardsBaseViewController(
            tabs: tabs,
            activeTab: activeMenu,
            flags: r.resolve(RuuviLocalFlags.self)!
        )
        viewController.view.backgroundColor = .systemGray
        let presenter = NewCardsBasePresenter(
            measurementPresenter: cardsMeasurementViewPresenter,
            graphPresenter: cardsGraphViewPresenter,
            alertsPresenter: cardsAlertsViewPresenter,
            settingsPresenter: cardsSettingsViewPresenter,
        )
        presenter.configure(
            for: snapshot,
            snapshots: snapshots,
            ruuviTagSensors: ruuviTagSensors,
            sensorSettings: sensorSettings,
            activeMenu: activeMenu
        )
        presenter.view = viewController
        viewController.output = presenter

        cardsRouter = CardsRouter()
        cardsRouter.transitionHandler = viewController
        presenter.router = cardsRouter

        cardsBaseViewPresenter = presenter
        cardsBaseViewController = viewController
        return viewController
    }
}

// MARK: Measurement
private extension CardsCoordinator {
    func createMeasurementViewController() -> NewCardsMeasurementViewController {
        let viewController = NewCardsMeasurementViewController()
        viewController.view.backgroundColor = .systemRed
        let presenter = NewCardsMeasurementPresenter()
        presenter.view = viewController
        viewController.output = presenter
        cardsMeasurementViewPresenter = presenter
        return viewController
    }
}

// MARK: Graph
private extension CardsCoordinator {
    func createGraphViewController() -> NewCardsGraphViewController {
        let viewController = NewCardsGraphViewController()
        viewController.view.backgroundColor = .systemBlue
        let presenter = NewCardsGraphPresenter()
        presenter.view = viewController
        viewController.output = presenter
        cardsGraphViewPresenter = presenter
        return viewController
    }
}

// MARK: Alerts
private extension CardsCoordinator {
    func createAlertsViewController() -> NewCardsAlertsViewController {
        let viewController = NewCardsAlertsViewController()
        viewController.view.backgroundColor = .cyan
        let presenter = NewCardsAlertsPresenter()
        presenter.view = viewController
        viewController.output = presenter
        cardsAlertsViewPresenter = presenter
        return viewController
    }
}

// MARK: Settings
private extension CardsCoordinator {
    func createSettingsViewController() -> NewCardsSettingsViewController {
        let viewController = NewCardsSettingsViewController()
        viewController.view.backgroundColor = .systemOrange
        let presenter = NewCardsSettingsPresenter()
        presenter.view = viewController
        viewController.output = presenter
        cardsSettingsViewPresenter = presenter
        return viewController
    }
}

// ROUGH works

// Presenters
class NewCardsMeasurementPresenter: NSObject, NewCardsMeasurementViewOutput,
                                    CardsMeasurementPresenterInput {
    func start() {
        print("Measurement Start")
    }

    func stop() {
        print("Measurement Stop")
    }

    func activeSnapshotDidChange(to snapshot: RuuviTagCardSnapshot) {
        //
    }

    weak var view: NewCardsMeasurementViewInput?
}
class NewCardsGraphPresenter: NSObject, NewCardsGraphViewOutput, CardsGraphPresenterInput {
    func start() {
        print("Graph Start")
    }

    func stop() {
        print("Graph Stop")
    }

    func activeSnapshotDidChange(to snapshot: RuuviTagCardSnapshot) {
        print("Graph")
    }

    weak var view: NewCardsGraphViewInput?
}
class NewCardsAlertsPresenter: NSObject, NewCardsAlertsViewOutput, CardsAlertsPresenterInput {
    func start() {
        print("Alert start")
    }

    func stop() {
        print("Alert stop")
    }

    func activeSnapshotDidChange(to snapshot: RuuviTagCardSnapshot) {
        //
    }

    weak var view: NewCardsAlertsViewInput?
}
class NewCardsSettingsPresenter: NSObject, NewCardsSettingsViewOutput, CardsSettingsPresenterInput {
    weak var view: NewCardsSettingsViewInput?

    func start() {
        print("Alert start")
    }

    func stop() {
        print("Alert stop")
    }

    func activeSnapshotDidChange(to snapshot: RuuviTagCardSnapshot) {
        //
    }
}

// Views
class NewCardsMeasurementViewController: UIViewController, NewCardsMeasurementViewInput {
    weak var output: NewCardsMeasurementViewOutput?
}
class NewCardsGraphViewController: UIViewController, NewCardsGraphViewInput {
    weak var output: NewCardsGraphViewOutput?
}
class NewCardsAlertsViewController: UIViewController, NewCardsAlertsViewInput {
    weak var output: NewCardsAlertsViewOutput?
}
class NewCardsSettingsViewController: UIViewController, NewCardsSettingsViewInput {
    weak var output: NewCardsSettingsViewOutput?
}

// Protocols view
protocol NewCardsMeasurementViewOutput: AnyObject {}
protocol NewCardsGraphViewOutput: AnyObject {}
protocol NewCardsAlertsViewOutput: AnyObject {}
protocol NewCardsSettingsViewOutput: AnyObject {}


protocol NewCardsMeasurementViewInput: AnyObject {}
protocol NewCardsGraphViewInput: AnyObject {}
protocol NewCardsAlertsViewInput: AnyObject {}
protocol NewCardsSettingsViewInput: AnyObject {}

// Protocols Presenters
protocol CardsMeasurementPresenterOutput: AnyObject {
    func measurementPresenter(
        _ presenter: NewCardsMeasurementPresenter,
        didSelectSnapshot snapshot: RuuviTagCardSnapshot
    )
    func measurementPresenter(
        _ presenter: NewCardsMeasurementPresenter,
        didNavigateToIndex index: Int
    )
    func measurementPresenter(
        _ presenter: NewCardsMeasurementPresenter,
        didRequestMeasurementDetails type: MeasurementType
    )
}
protocol CardsGraphPresenterOutput: AnyObject {}
protocol CardsAlertsPresenterOutput: AnyObject {}
protocol CardsSettingsPresenterOutput: AnyObject {}

// MARK: - Input Protocols for Cross-Presenter Communication

protocol CardsBasePresenterInput: AnyObject {
    func configure(
        for snapshot: RuuviTagCardSnapshot,
        snapshots: [RuuviTagCardSnapshot],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        activeMenu: CardsMenuType
    )
}

protocol CardsMeasurementPresenterInput: AnyObject {
    func start()
    func stop()
    func activeSnapshotDidChange(to snapshot: RuuviTagCardSnapshot)
}

protocol CardsGraphPresenterInput: AnyObject {
    func start()
    func stop()
    func activeSnapshotDidChange(to snapshot: RuuviTagCardSnapshot)
}

protocol CardsAlertsPresenterInput: AnyObject {
    func start()
    func stop()
    func activeSnapshotDidChange(to snapshot: RuuviTagCardSnapshot)
}

protocol CardsSettingsPresenterInput: AnyObject {
    func start()
    func stop()
    func activeSnapshotDidChange(to snapshot: RuuviTagCardSnapshot)
}
