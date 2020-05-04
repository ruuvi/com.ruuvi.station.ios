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
        presenter.gattService = r.resolve(GATTService.self)
        presenter.exportService = r.resolve(ExportService.self)
        presenter.alertService = r.resolve(AlertService.self)
        presenter.background = r.resolve(BTBackground.self)
        presenter.mailComposerPresenter = r.resolve(MailComposerPresenter.self)
        presenter.feedbackEmail = r.property("Feedback Email")!
        presenter.feedbackSubject = r.property("Feedback Subject")!
        presenter.infoProvider = r.resolve(InfoProvider.self)
        presenter.ruuviTagReactor = r.resolve(RuuviTagReactor.self)
        presenter.ruuviTagTank = r.resolve(RuuviTagTank.self)
        view.output = presenter
    }
}
