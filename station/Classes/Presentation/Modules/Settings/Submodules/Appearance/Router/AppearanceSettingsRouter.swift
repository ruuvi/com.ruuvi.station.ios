import LightRoute

class AppearanceSettingsRouter: AppearanceSettingsRouterInput {
    weak var transitionHandler: UIViewController?

    func dismiss() {
        try? transitionHandler?.closeCurrentModule().perform()
    }

    func openSelection(with viewModel: AppearanceSettingsViewModel) {
        let factory: ASSelectionModuleFactory = ASSelectionModuleFactoryImpl()
        let module = factory.create(with: "app_theme".localized())

        transitionHandler?
            .navigationController?
            .pushViewController(
                module,
                animated: true
            )

        if let output = module.output as? ASSelectionModuleInput {
            output.configure(viewModel: viewModel)
        }
    }
}
