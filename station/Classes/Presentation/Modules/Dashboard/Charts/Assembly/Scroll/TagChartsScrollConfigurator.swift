import Foundation
import BTKit
import RuuviStorage
import RuuviReactor
import RuuviLocal
import RuuviPool
import RuuviService
import RuuviNotifier
import RuuviPresenters

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
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.ruuviStorage = r.resolve(RuuviStorage.self)
        presenter.ruuviReactor = r.resolve(RuuviReactor.self)
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.alertPresenter = r.resolve(AlertPresenter.self)
        presenter.mailComposerPresenter = r.resolve(MailComposerPresenter.self)
        presenter.alertService = r.resolve(RuuviServiceAlert.self)
        presenter.alertHandler = r.resolve(RuuviNotifier.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.background = r.resolve(BTBackground.self)
        presenter.feedbackEmail = r.property("Feedback Email")!
        presenter.feedbackSubject = r.property("Feedback Subject")!
        presenter.infoProvider = r.resolve(InfoProvider.self)
        presenter.interactor = interactor
        presenter.ruuviSensorPropertiesService = r.resolve(RuuviServiceSensorProperties.self)

        interactor.gattService = r.resolve(GATTService.self)
        interactor.settings = r.resolve(RuuviLocalSettings.self)
        interactor.exportService = r.resolve(RuuviServiceExport.self)
        interactor.ruuviReactor = r.resolve(RuuviReactor.self)
        interactor.ruuviPool = r.resolve(RuuviPool.self)
        interactor.ruuviStorage = r.resolve(RuuviStorage.self)
        interactor.ruuviSensorRecords = r.resolve(RuuviServiceSensorRecords.self)
        interactor.featureToggleService = r.resolve(FeatureToggleService.self)
        interactor.presenter = presenter

        view.output = presenter
    }
}
