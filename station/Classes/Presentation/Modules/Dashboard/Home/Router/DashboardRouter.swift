import LightRoute
import Foundation
import UIKit
import RuuviOntology
import RuuviLocal
import RuuviVirtual

class DashboardRouter: NSObject, DashboardRouterInput {
    weak var transitionHandler: UIViewController!
    weak var delegate: DashboardRouterDelegate!
    private weak var dfuModule: DFUModuleInput?
    private weak var backgroundSelectionModule: BackgroundSelectionModuleInput?
    weak var cards: CardsModuleInput?
    var settings: RuuviLocalSettings!

    // swiftlint:disable weak_delegate
    var menuTableInteractiveTransition: MenuTableTransitioningDelegate!
    // swiftlint:enable weak_delegate

    private var menuTableTransition: MenuTableTransitioningDelegate!

    func openMenu(output: MenuModuleOutput) {
        let factory = StoryboardFactory(storyboardName: "Menu")
        try! transitionHandler
            .forStoryboard(factory: factory, to: MenuModuleInput.self)
            .apply(to: { (viewController) in
                viewController.modalPresentationStyle = .custom
                let manager = MenuTableTransitionManager(container: self.transitionHandler, menu: viewController)
                self.menuTableTransition = MenuTableTransitioningDelegate(manager: manager)
            })
            .add(transitioningDelegate: menuTableTransition)
            .then({ (module) -> Any? in
                module.configure(output: output)
            })
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
        guard let url = URL(string: "Menu.Measure.URL.IOS".localized()) else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func openRuuviProductsPage() {
        guard let url = URL(string: "Ruuvi.BuySensors.URL.IOS".localized()) else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func openRuuviProductsPageFromMenu() {
        guard let url = URL(string: "Ruuvi.BuySensors.Menu.URL.IOS".localized()) else {
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

    func openTagSettings(ruuviTag: RuuviTagSensor,
                         latestMeasurement: RuuviTagSensorRecord?,
                         sensorSettings: SensorSettings?,
                         output: TagSettingsModuleOutput) {
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
            presenter.configure(ruuviTag: ruuviTag,
                             latestMeasurement: latestMeasurement,
                             sensorSettings: sensorSettings)
        }
    }

    func openVirtualSensorSettings(
        sensor: VirtualTagSensor,
        temperature: Temperature?
    ) {
        let factory = StoryboardFactory(storyboardName: "WebTagSettings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: WebTagSettingsModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ (module) -> Any? in
                module.configure(sensor: sensor, temperature: temperature)
            })
    }

    // swiftlint:disable:next function_parameter_count
    func openCardImageView(with viewModels: [CardsViewModel],
                           ruuviTagSensors: [AnyRuuviTagSensor],
                           virtualSensors: [AnyVirtualTagSensor],
                           sensorSettings: [SensorSettings],
                           scrollTo: CardsViewModel?,
                           showCharts: Bool,
                           output: CardsModuleOutput) {
        let factory: CardsViewModuleFactory = CardsViewModuleFactoryImpl()
        let module = factory.create()
        if let output = module.output as? CardsModuleInput {
            cards = output
        }

        // Remove any cards view controller from stack if exists already
        if let navigationController = transitionHandler.navigationController,
            navigationController
            .containsViewController(ofKind: CardsViewController.self) {
            transitionHandler
                .navigationController?
                .removeAnyViewControllers(ofKind: CardsViewController.self)
        }

        transitionHandler
            .navigationController?
            .pushViewController(
                module,
                animated: true
            )
        if let cards = cards {
            cards.configure(output: output)
            cards.configure(viewModels: viewModels,
                            ruuviTagSensors: ruuviTagSensors,
                            virtualSensors: virtualSensors,
                            sensorSettings: sensorSettings)
            cards.configure(scrollTo: scrollTo,
                            openChart: showCharts)
        }
    }

    // swiftlint:disable:next function_parameter_count
    func openTagSettings(with viewModels: [CardsViewModel],
                         ruuviTagSensors: [AnyRuuviTagSensor],
                         virtualSensors: [AnyVirtualTagSensor],
                         sensorSettings: [SensorSettings],
                         scrollTo: CardsViewModel?,
                         ruuviTag: RuuviTagSensor,
                         latestMeasurement: RuuviTagSensorRecord?,
                         sensorSetting: SensorSettings?,
                         output: CardsModuleOutput) {
        let cardsFactory: CardsViewModuleFactory = CardsViewModuleFactoryImpl()
        let cardsModule = cardsFactory.create()

        let settingsFactory: TagSettingsModuleFactory = TagSettingsModuleFactoryImpl()
        let settingsModule = settingsFactory.create()

        if let cardsPresenter = cardsModule.output as? CardsModuleInput,
           let cardsPresenterOutput = cardsPresenter as? TagSettingsModuleOutput,
           let settingsPresenter = settingsModule.output as? TagSettingsModuleInput {
            cardsPresenter.configure(output: output)
            cardsPresenter.configure(viewModels: viewModels,
                            ruuviTagSensors: ruuviTagSensors,
                            virtualSensors: virtualSensors,
                            sensorSettings: sensorSettings)
            cardsPresenter.configure(scrollTo: scrollTo,
                            openChart: false)
            if let cardsOutput = cardsModule as? CardsViewOutput {
                cardsOutput.viewDidLoad()
            }

            settingsPresenter.configure(output: cardsPresenterOutput)
            settingsPresenter.configure(ruuviTag: ruuviTag,
                             latestMeasurement: latestMeasurement,
                             sensorSettings: sensorSetting)
        }

        transitionHandler.navigationController?.setViewControllers([
            transitionHandler, cardsModule, settingsModule
        ], animated: true)
    }

    func openUpdateFirmware(ruuviTag: RuuviTagSensor) {
        let factory: DFUModuleFactory = DFUModuleFactoryImpl()
        let module = factory.create(for: ruuviTag)
        self.dfuModule = module
        transitionHandler
            .navigationController?
            .pushViewController(
                module.viewController,
                animated: true
            )
        transitionHandler
            .navigationController?
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
        let module = factory.create(for: ruuviTag, virtualTag: nil)
        self.backgroundSelectionModule = module
        transitionHandler
            .navigationController?
            .pushViewController(
                module.viewController,
                animated: true
            )

    }

    func openBackgroundSelectionView(virtualSensor: VirtualTagSensor) {
        let factory: BackgroundSelectionModuleFactory = BackgroundSelectionModuleFactoryImpl()
        let module = factory.create(for: nil, virtualTag: virtualSensor)
        self.backgroundSelectionModule = module
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
            .forStoryboard(factory: factory,
                           to: ShareModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ (module) -> Any? in
                module.configure(sensor: sensor)
            })
    }

}

extension DashboardRouter: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(
        _ presentationController: UIPresentationController
    ) -> Bool {
        return delegate.shouldDismissDiscover()
    }
}
