import UIKit
import RuuviLocal

protocol AppearanceSettingsModuleFactory {
    func create() -> AppearanceSettingsTableViewController
}

final class AppearanceSettingsModuleFactoryImpl: AppearanceSettingsModuleFactory {
    func create() -> AppearanceSettingsTableViewController {
        let r = AppAssembly.shared.assembler.resolver

        let view = AppearanceSettingsTableViewController(
            title: "settings_appearance".localized()
        )
        let router = AppearanceSettingsRouter()
        router.transitionHandler = view

        let presenter = AppearanceSettingsPresenter()
        presenter.view = view
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.router = router

        view.output = presenter
        return view
    }
}
