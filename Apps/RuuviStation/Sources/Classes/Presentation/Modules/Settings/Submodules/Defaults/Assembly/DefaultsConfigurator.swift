import Foundation
import RuuviLocal
import RuuviService
import RuuviUser

class DefaultsConfigurator {
    func configure(view: DefaultsViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = DefaultsRouter()
        router.transitionHandler = view

        let presenter = DefaultsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.flags = r.resolve(RuuviLocalFlags.self)
        presenter.ruuviUser = r.resolve(RuuviUser.self)
        presenter.ruuviAppSettingsService = r.resolve(RuuviServiceAppSettings.self)

        view.output = presenter
    }
}
