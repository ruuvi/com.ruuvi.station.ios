import Foundation
import RuuviContext
import RuuviStorage

class AboutConfigurator {
    func configure(view: AboutViewController) {
        let r = AppAssembly.shared.assembler.resolver
        let router = AboutRouter()
        router.transitionHandler = view

        let presenter = AboutPresenter()
        presenter.view = view
        presenter.router = router
        presenter.ruuviStorage = r.resolve(RuuviStorage.self)
        presenter.realmContext = r.resolve(RealmContext.self)
        presenter.sqliteContext = r.resolve(SQLiteContext.self)
        view.output = presenter
    }
}
