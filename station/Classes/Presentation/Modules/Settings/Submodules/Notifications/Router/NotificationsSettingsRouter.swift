import LightRoute
import UIKit

class  NotificationsSettingsRouter: NotificationsSettingsRouterInput {
    weak var transitionHandler: UIViewController?

    func dismiss() {
        try? transitionHandler?.closeCurrentModule().perform()
    }

    func openSelection(with viewModel: PushAlertSoundSelectionViewModel) {
        let factory: PushAlertSoundSelectionModuleFactory = PushAlertSoundSelectionModuleFactoryImpl()
        let module = factory.create(with: viewModel.title)

        transitionHandler?
            .navigationController?
            .pushViewController(
                module,
                animated: true
            )

        if let output = module.output as? PushAlertSoundSelectionModuleInput {
            output.configure(viewModel: viewModel)
        }
    }
}
