import RuuviLocal
import RuuviLocalization
import UIKit

protocol AppearanceSettingsModuleFactory {
    func create() -> AppearanceSettingsTableViewController
}

final class AppearanceSettingsModuleFactoryImpl: AppearanceSettingsModuleFactory {
    func create() -> AppearanceSettingsTableViewController {
        let r = AppAssembly.shared.assembler.resolver

        let view = AppearanceSettingsTableViewController(
            title: RuuviLocalization.settingsAppearance
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
