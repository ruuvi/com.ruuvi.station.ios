import Foundation
import BTKit

class TagChartsScrollConfigurator {
    func configure(view: TagChartsScrollViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let interactor = TagChartsInteractor()
        let presenter = TagChartsPresenter()
        let router = TagChartsRouter()

        router.transitionHandler = view

        presenter.view = view
        presenter.router = router
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.backgroundPersistence = r.resolve(BackgroundPersistence.self)
        presenter.settings = r.resolve(Settings.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.ruuviTagTrunk = r.resolve(RuuviTagTrunk.self)
        presenter.ruuviTagReactor = r.resolve(RuuviTagReactor.self)
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.alertPresenter = r.resolve(AlertPresenter.self)
        presenter.mailComposerPresenter = r.resolve(MailComposerPresenter.self)
        presenter.alertService = r.resolve(AlertService.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.background = r.resolve(BTBackground.self)
        presenter.feedbackEmail = r.property("Feedback Email")!
        presenter.feedbackSubject = r.property("Feedback Subject")!
        presenter.infoProvider = r.resolve(InfoProvider.self)
        presenter.interactor = interactor

        interactor.gattService = r.resolve(GATTService.self)
        interactor.settings = r.resolve(Settings.self)
        interactor.exportService = r.resolve(ExportService.self)
        interactor.keychainService = r.resolve(KeychainService.self)
        interactor.networkService = r.resolve(NetworkService.self)
        interactor.ruuviTagReactor = r.resolve(RuuviTagReactor.self)
        interactor.ruuviTagTank = r.resolve(RuuviTagTank.self)
        interactor.ruuviTagTrunk = r.resolve(RuuviTagTrunk.self)
        interactor.presenter = presenter

        view.output = presenter
    }
}
