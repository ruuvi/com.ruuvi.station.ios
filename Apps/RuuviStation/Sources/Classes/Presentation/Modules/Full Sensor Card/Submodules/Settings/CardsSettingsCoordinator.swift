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
import RuuviLocalization

protocol CardsSettingsCoordinatorDelegate: AnyObject {
    func cardsSettingsCoordinatorDidDismiss(_ coordinator: CardsSettingsCoordinator)
}

// TODO: Remove this when new menu implementation is finished
class CardsSettingsCoordinator: RuuviCoordinator {
    private var cardsSettingsViewController: CardsSettingsViewController!
    private var cardsSettingsViewPresenter: CardsSettingsPresenter!
    private var router: CardsSettingsRouter!
    private var snapshot: RuuviTagCardSnapshot!
    private var ruuviTagSensor: RuuviTagSensor!
    private var sensorSettings: SensorSettings?

    private weak var delegate: CardsSettingsCoordinatorDelegate?

    init(
        baseViewController: UIViewController,
        for snapshot: RuuviTagCardSnapshot,
        ruuviTagSensor: RuuviTagSensor,
        sensorSettings: SensorSettings?,
        delegate: CardsSettingsCoordinatorDelegate?,
    ) {
        super.init(baseViewController: baseViewController)
        self.snapshot = snapshot
        self.ruuviTagSensor = ruuviTagSensor
        self.sensorSettings = sensorSettings
        self.delegate = delegate
    }

    override func start() {
        super.start()

        cardsSettingsViewController = createSettingsViewController(
            snapshot: snapshot
        )
        baseViewController.navigationController?.pushViewController(
            cardsSettingsViewController,
            animated: true
        )
    }

    override func stop() {
        super.stop()
        delegate = nil
        cardsSettingsViewPresenter.dismiss(completion: nil)
    }
}

// MARK: Settings
private extension CardsSettingsCoordinator {
    func createSettingsViewController(
        snapshot: RuuviTagCardSnapshot
    ) -> CardsSettingsViewController {
        router = CardsSettingsRouter()
        let r = AppAssembly.shared.assembler.resolver
        let presenter = CardsSettingsPresenter(
            ruuviSensorPropertiesService: r.resolve(RuuviServiceSensorProperties.self)!,
            measurementService: r.resolve(RuuviServiceMeasurement.self)!,
            settings: r.resolve(RuuviLocalSettings.self)!,
            errorPresenter: r.resolve(ErrorPresenter.self)!,
            activityPresenter: r.resolve(ActivityPresenter.self)!
        )
        let viewController = CardsSettingsViewController(
            snapshot: snapshot
        )
        viewController.output = presenter
        presenter.view = viewController
        presenter.router = router
        presenter.output = self
        presenter
            .configure(
                with: snapshot,
                sensor: ruuviTagSensor.any,
                settings: sensorSettings
            )
        presenter.start()
        router.transitionHandler = viewController
        cardsSettingsViewPresenter = presenter
        return viewController
    }
}

extension CardsSettingsCoordinator: CardsSettingsPresenterOutput {
    func cardSettingsDidDeleteDevice(
        module: CardsSettingsPresenterInput,
        ruuviTag: RuuviTagSensor
    ) {
        // TODO: Implement delete callback if needed or remove this.
        module.dismiss(completion: { [weak self] in
            guard let self else { return }
            self.baseViewController.navigationController?.popViewController(animated: true)
            self.delegate?.cardsSettingsCoordinatorDidDismiss(self)
        })
    }

    func cardSettingsDidDismiss(module: CardsSettingsPresenterInput) {
        module.dismiss(completion: { [weak self] in
            guard let self else { return }
            self.baseViewController.navigationController?.popViewController(animated: true)
            self.delegate?.cardsSettingsCoordinatorDidDismiss(self)
        })
    }
}
