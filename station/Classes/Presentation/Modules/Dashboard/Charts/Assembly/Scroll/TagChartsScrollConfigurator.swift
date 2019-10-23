import Foundation
import BTKit

class TagChartsScrollConfigurator {
    func configure(view: TagChartsScrollViewController) {
        let r = AppAssembly.shared.assembler.resolver
        
        let router = TagChartsRouter()
        router.transitionHandler = view
        
        let presenter = TagChartsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.realmContext = r.resolve(RealmContext.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.backgroundPersistence = r.resolve(BackgroundPersistence.self)
        presenter.settings = r.resolve(Settings.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.ruuviTagService = r.resolve(RuuviTagService.self)
        
        view.output = presenter
    }
}
