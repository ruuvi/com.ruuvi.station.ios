import Foundation
import LightRoute
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import UIKit

class DashboardRouter: NSObject, DashboardRouterInput {
    weak var transitionHandler: UIViewController!
    weak var delegate: DashboardRouterDelegate!
    private weak var dfuModule: DFUModuleInput?
    private weak var backgroundSelectionModule: BackgroundSelectionModuleInput?
    var settings: RuuviLocalSettings!
    var cardsCoordinator: CardsCoordinator!

    // swiftlint:disable weak_delegate
    var menuTableInteractiveTransition: MenuTableTransitioningDelegate!
    // swiftlint:enable weak_delegate

    private var menuTableTransition: MenuTableTransitioningDelegate!

    func openMenu(output: MenuModuleOutput) {
        let factory = StoryboardFactory(storyboardName: "Menu")
        try! transitionHandler
            .forStoryboard(factory: factory, to: MenuModuleInput.self)
            .apply(to: { viewController in
                viewController.modalPresentationStyle = .custom
                let manager = MenuTableTransitionManager(container: self.transitionHandler, menu: viewController)
                self.menuTableTransition = MenuTableTransitioningDelegate(manager: manager)
            })
            .add(transitioningDelegate: menuTableTransition)
            .then { module -> Any? in
                module.configure(output: output)
            }
    }

    func openDiscover(delegate: DiscoverRouterDelegate) {
        let discoverRouter = DiscoverRouter()
        discoverRouter.delegate = delegate
        let viewController = discoverRouter.viewController
        let navigationController = UINavigationController(rootViewController: viewController)
        transitionHandler.present(navigationController, animated: true)
    }

    func openSettings() {
        let factory = StoryboardFactory(storyboardName: "Settings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: SettingsModuleInput.self)
            .perform()
    }

    func openAbout() {
        let factory = StoryboardFactory(storyboardName: "About")
        try! transitionHandler
            .forStoryboard(factory: factory, to: AboutModuleInput.self)
            .perform()
    }

    func openWhatToMeasurePage() {
        guard let url = URL(string: RuuviLocalization.Menu.Measure.Url.ios)
        else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func openRuuviProductsPage() {
        guard let url = URL(string: RuuviLocalization.Ruuvi.BuySensors.Url.ios)
        else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func openRuuviProductsPageFromMenu() {
        guard let url = URL(string: RuuviLocalization.Ruuvi.BuySensors.Menu.Url.ios)
        else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func openSignIn(output: SignInBenefitsModuleOutput) {
        let factory: SignInBenefitsModuleFactory = SignInPromoModuleFactoryImpl()
        let module = factory.create()

        let navigationController = UINavigationController(
            rootViewController: module)
        transitionHandler.present(navigationController, animated: true)

        if let presenter = module.output as? SignInBenefitsModuleInput {
            presenter.configure(output: output)
        }

        AppUtility.lockOrientation(.portrait)
    }

    func openTagSettings(
        ruuviTag: RuuviTagSensor,
        latestMeasurement: RuuviTagSensorRecord?,
        sensorSettings: SensorSettings?,
        output: TagSettingsModuleOutput
    ) {
        let factory: TagSettingsModuleFactory = TagSettingsModuleFactoryImpl()
        let module = factory.create()
        transitionHandler
            .navigationController?
            .pushViewController(
                module,
                animated: true
            )
        if let presenter = module.output as? TagSettingsModuleInput {
            presenter.configure(output: output)
            presenter.configure(
                ruuviTag: ruuviTag,
                latestMeasurement: latestMeasurement,
                sensorSettings: sensorSettings
            )
        }
    }

    // swiftlint:disable:next function_parameter_count
    func openFullSensorCard(
        for snapshot: RuuviTagCardSnapshot,
        snapshots: [RuuviTagCardSnapshot],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        activeMenu: CardsMenuType,
        openSettings: Bool
    ) {
        cardsCoordinator = CardsCoordinator(
            baseViewController: transitionHandler,
            for: snapshot,
            snapshots: snapshots,
            ruuviTagSensors: ruuviTagSensors,
            sensorSettings: sensorSettings,
            activeMenu: activeMenu,
            delegate: self,
            showSettings: openSettings
        )
        cardsCoordinator.start()
    }

    func openUpdateFirmware(ruuviTag: RuuviTagSensor) {
        let factory: DFUModuleFactory = DFUModuleFactoryImpl()
        let module = factory.create(for: ruuviTag)
        module.output = self
        dfuModule = module
        transitionHandler
            .present(
                module.viewController,
                animated: true
            )
        module.viewController
            .presentationController?
            .delegate = self
    }

    func openMyRuuviAccount() {
        let factory = StoryboardFactory(storyboardName: "MyRuuvi")
        try! transitionHandler
            .forStoryboard(factory: factory, to: MyRuuviAccountModuleInput.self)
            .perform()
    }

    func openBackgroundSelectionView(ruuviTag: RuuviTagSensor) {
        let factory: BackgroundSelectionModuleFactory = BackgroundSelectionModuleFactoryImpl()
        let module = factory.create(for: ruuviTag)
        backgroundSelectionModule = module
        transitionHandler
            .navigationController?
            .pushViewController(
                module.viewController,
                animated: true
            )
    }

    func openShare(for sensor: RuuviTagSensor) {
        let restorationId = "ShareViewController"
        let factory = StoryboardFactory(storyboardName: "Share", bundle: .main, restorationId: restorationId)
        try! transitionHandler
            .forStoryboard(
                factory: factory,
                to: ShareModuleInput.self
            )
            .to(preferred: .navigation(style: .push))
            .then { module -> Any? in
                module.configure(sensor: sensor)
            }
    }

    func openRemove(
      for ruuviTag: RuuviTagSensor,
      output: SensorRemovalModuleOutput
    ) {
        let factory: SensorRemovalModuleFactory = SensorRemovalModuleFactoryImpl()
        let module = factory.create()
        transitionHandler
            .navigationController?
            .pushViewController(
                module,
                animated: true
            )
        if let presenter = module.output as? SensorRemovalModuleInput {
            presenter.configure(ruuviTag: ruuviTag, output: output)
        }
    }
}

extension DashboardRouter: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(
        _: UIPresentationController
    ) -> Bool {
        if let dfuModule {
            dfuModule.isSafeToDismiss()
        } else {
            delegate.shouldDismissDiscover()
        }
    }
}

extension DashboardRouter: CardsCoordinatorDelegate {
    func cardsCoordinatorDidDismiss(_ coordinator: CardsCoordinator) {
        cardsCoordinator.stop()
        cardsCoordinator = nil
    }
}

extension DashboardRouter: DFUModuleOutput {
    func dfuModuleSuccessfullyUpgraded(_ dfuModule: DFUModuleInput) {
        dfuModule.viewController.dismiss(animated: true)
    }
}
