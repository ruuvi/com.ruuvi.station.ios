import UIKit
import RuuviOntology
import RuuviLocal
import RuuviService
import RuuviCore
import RuuviDaemon
import RuuviUser
import RuuviPresenters
import BTKit
import RuuviReactor
import RuuviPool
import RuuviStorage
import RuuviNotifier

protocol CardsCoordinatorDelegate: AnyObject {
    func cardsCoordinatorDidDismiss(_ coordinator: CardsCoordinator)
}

class CardsCoordinator: RuuviCoordinator {
    private var cardsBaseViewController: CardsBaseViewController!
    private var cardsMeasurementViewController: CardsMeasurementViewController!
    private var cardsGraphViewController: CardsGraphViewController!
    private var cardsAlertsViewController: CardsAlertsViewController!
    private var cardsSettingsViewController: CardsSettingsViewController!

    private var cardsBaseViewPresenter: CardsBasePresenter!
    private var cardsMeasurementViewPresenter: CardsMeasurementPresenter!
    private var cardsGraphViewPresenter: CardsGraphPresenter!
    private var cardsAlertsViewPresenter: CardsAlertsPresenter!
    private var cardsSettingsViewPresenter: CardsSettingsPresenter!

    private var cardsRouter: CardsRouter!
    private var graphInteractor: TagChartsViewInteractor!

    private var snapshot: RuuviTagCardSnapshot!
    private var snapshots: [RuuviTagCardSnapshot] = []
    private var ruuviTagSensors: [AnyRuuviTagSensor] = []
    private var sensorSettings: [SensorSettings] = []
    private var activeMenu: CardsMenuType = .measurement
    private var showSettings: Bool = false // Legacy

    private var tabs: [CardsMenuType: UIViewController] = [:]

    private weak var delegate: CardsCoordinatorDelegate?

    init(
        baseViewController: UIViewController,
        for snapshot: RuuviTagCardSnapshot,
        snapshots: [RuuviTagCardSnapshot],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        activeMenu: CardsMenuType,
        delegate: CardsCoordinatorDelegate?,
        showSettings: Bool
    ) {
        super.init(baseViewController: baseViewController)
        self.snapshot = snapshot
        self.snapshots = snapshots
        self.ruuviTagSensors = ruuviTagSensors
        self.sensorSettings = sensorSettings
        self.activeMenu = activeMenu
        self.showSettings = showSettings
        self.delegate = delegate
    }

    override func start() {
        super.start()

        tabs = createTabViewControllers()
        cardsBaseViewController = createBaseViewController()

        if showSettings {
            let settingsFactory: TagSettingsModuleFactory = TagSettingsModuleFactoryImpl()
            let settingsModule = settingsFactory.create()

            if let settingsPresenter = settingsModule.output as? TagSettingsModuleInput,
               let ruuviTag = ruuviTagSensors.first(where: {
                   $0.luid?.value == snapshot.identifierData.luid?.value ||
                   $0.macId?.value == snapshot.identifierData.mac?.value
               }) {
                settingsPresenter.configure(output: cardsBaseViewPresenter)
                settingsPresenter.configure(
                    ruuviTag: ruuviTag,
                    latestMeasurement: snapshot.latestRawRecord,
                    sensorSettings: sensorSettings.first(where: {
                        $0.luid?.value == ruuviTag.luid?.value ||
                        $0.macId?.value == ruuviTag.macId?.value
                    })
                )
            }

            baseViewController.navigationController?.setViewControllers(
                [
                    baseViewController,
                    cardsBaseViewController,
                    settingsModule,
                ],
                animated: true
            )
        } else {
            baseViewController.navigationController?.pushViewController(
                cardsBaseViewController,
                animated: true
            )
        }
    }

    override func stop() {
        super.stop()
        delegate = nil
        // TODO: Cleanup
        cardsBaseViewPresenter.dismiss(completion: { [weak self] in
            self?.cardsMeasurementViewPresenter.stop()
            self?.cardsGraphViewPresenter.stop()
            self?.cardsAlertsViewPresenter.stop()
            self?.cardsSettingsViewPresenter.stop()

            self?.cardsMeasurementViewPresenter = nil
            self?.cardsGraphViewPresenter = nil
            self?.cardsAlertsViewPresenter = nil
            self?.cardsSettingsViewPresenter = nil

            self?.cardsMeasurementViewController = nil
            self?.cardsGraphViewController = nil
            self?.cardsAlertsViewController = nil
            self?.cardsSettingsViewController = nil
        })
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

// TODO: Move these below codes to separate factory class
// MARK: Base
private extension CardsCoordinator {
    func createBaseViewController() -> CardsBaseViewController {
        let r = AppAssembly.shared.assembler.resolver

        let ruuviCloudService = RuuviCloudService(
            cloudSyncDaemon: r.resolve(RuuviDaemonCloudSync.self)!,
            cloudSyncService: r.resolve(RuuviServiceCloudSync.self)!,
            cloudNotificationService: r.resolve(RuuviServiceCloudNotification.self)!,
            authService: r.resolve(RuuviServiceAuth.self)!,
            ruuviUser: r.resolve(RuuviUser.self)!,
            settings: r.resolve(RuuviLocalSettings.self)!,
            pnManager: r.resolve(RuuviCorePN.self)!
        )

        let viewController = CardsBaseViewController(
            tabs: tabs,
            activeTab: activeMenu,
            flags: r.resolve(RuuviLocalFlags.self)!
        )
        let presenter = CardsBasePresenter(
            measurementPresenter: cardsMeasurementViewPresenter,
            graphPresenter: cardsGraphViewPresenter,
            alertsPresenter: cardsAlertsViewPresenter,
            settingsPresenter: cardsSettingsViewPresenter,
            foreground: r.resolve(BTForeground.self)!,
            ruuviCloudService: ruuviCloudService,
            settings: r.resolve(RuuviLocalSettings.self)!,
            connectionPersistence: r.resolve(RuuviLocalConnections.self)!,
            errorPresenter: r.resolve(ErrorPresenter.self)!,
            featureToggleService: r.resolve(FeatureToggleService.self)!

        )
        presenter.configure(
            for: snapshot,
            snapshots: snapshots,
            ruuviTagSensors: ruuviTagSensors,
            sensorSettings: sensorSettings,
            activeMenu: activeMenu,
            output: self
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
    func createMeasurementViewController() -> CardsMeasurementViewController {
        let viewController = CardsMeasurementViewController()
        viewController.view.backgroundColor = .clear
        let presenter = CardsMeasurementPresenter()
        presenter.view = viewController
        viewController.output = presenter
        cardsMeasurementViewPresenter = presenter
        return viewController
    }
}

// MARK: Graph
private extension CardsCoordinator {
    func createGraphViewController() -> CardsGraphViewController {
        let r = AppAssembly.shared.assembler.resolver

        let interactor = TagChartsViewInteractor()
        graphInteractor = interactor
        let presenter = CardsGraphPresenter(
            errorPresenter: r.resolve(ErrorPresenter.self)!,
            settings: r.resolve(RuuviLocalSettings.self)!,
            foreground: r.resolve(BTForeground.self)!,
            ruuviReactor: r.resolve(RuuviReactor.self)!,
            activityPresenter: r.resolve(ActivityPresenter.self)!,
            alertPresenter: r.resolve(AlertPresenter.self)!,
            measurementService: r.resolve(RuuviServiceMeasurement.self)!,
            exportService: r.resolve(RuuviServiceExport.self)!,
            alertService: r.resolve(RuuviServiceAlert.self)!,
            background: r.resolve(BTBackground.self)!,
            flags: r.resolve(RuuviLocalFlags.self)!
        )
        presenter.interactor = interactor

        interactor.gattService = r.resolve(GATTService.self)
        interactor.settings = r.resolve(RuuviLocalSettings.self)
        interactor.exportService = r.resolve(RuuviServiceExport.self)
        interactor.ruuviReactor = r.resolve(RuuviReactor.self)
        interactor.ruuviPool = r.resolve(RuuviPool.self)
        interactor.ruuviStorage = r.resolve(RuuviStorage.self)
        interactor.cloudSyncService = r.resolve(RuuviServiceCloudSync.self)
        interactor.ruuviSensorRecords = r.resolve(RuuviServiceSensorRecords.self)
        interactor.featureToggleService = r.resolve(FeatureToggleService.self)
        interactor.localSyncState = r.resolve(RuuviLocalSyncState.self)
        interactor.ruuviAppSettingsService = r.resolve(RuuviServiceAppSettings.self)
        interactor.presenter = presenter

        let viewController = CardsGraphViewController(
            output: presenter
        )
        viewController.view.backgroundColor = .clear
        viewController.output = presenter
        presenter.view = viewController
        viewController.measurementService = r.resolve(RuuviServiceMeasurement.self)!

        cardsGraphViewPresenter = presenter
        return viewController
    }
}

// MARK: Alerts
private extension CardsCoordinator {
    func createAlertsViewController() -> CardsAlertsViewController {
        let viewController = CardsAlertsViewController()
        viewController.view.backgroundColor = .gray
        let presenter = CardsAlertsPresenter()
        presenter.view = viewController
        viewController.output = presenter
        cardsAlertsViewPresenter = presenter
        return viewController
    }
}

// MARK: Settings
private extension CardsCoordinator {
    func createSettingsViewController() -> CardsSettingsViewController {
        let viewController = CardsSettingsViewController()
        viewController.view.backgroundColor = .gray
        let presenter = CardsSettingsPresenter()
        presenter.view = viewController
        viewController.output = presenter
        cardsSettingsViewPresenter = presenter
        return viewController
    }
}

extension CardsCoordinator: CardsBasePresenterOutput {
    func cardsViewDidDismiss(module: CardsBasePresenterInput) {
        module.dismiss(completion: { [weak self] in
            guard let self else { return }
            self.baseViewController.navigationController?.popViewController(animated: true)
            self.delegate?.cardsCoordinatorDidDismiss(self)
        })
    }
}
