import BTKit
import Foundation
import RuuviLocal
import RuuviNotifier
import RuuviOntology
import RuuviPool
import RuuviPresenters
import RuuviReactor
import RuuviService
import RuuviStorage

class TagChartsViewConfigurator {
    func configure(view: TagChartsViewController,
                   ruuviTag: AnyRuuviTagSensor)
    {
        let r = AppAssembly.shared.assembler.resolver

        let interactor = TagChartsViewInteractor()
        let presenter = TagChartsViewPresenter()

        presenter.view = view
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.ruuviStorage = r.resolve(RuuviStorage.self)
        presenter.ruuviReactor = r.resolve(RuuviReactor.self)
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.alertPresenter = r.resolve(AlertPresenter.self)
        presenter.mailComposerPresenter = r.resolve(MailComposerPresenter.self)
        presenter.measurementService = r.resolve(RuuviServiceMeasurement.self)
        presenter.alertService = r.resolve(RuuviServiceAlert.self)
        presenter.alertHandler = r.resolve(RuuviNotifier.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.background = r.resolve(BTBackground.self)
        presenter.feedbackEmail = PresentationConstants.feedbackEmail
        presenter.feedbackSubject = PresentationConstants.feedbackSubject
        presenter.infoProvider = r.resolve(InfoProvider.self)
        presenter.interactor = interactor
        presenter.ruuviSensorPropertiesService = r.resolve(RuuviServiceSensorProperties.self)
        presenter.exportService = r.resolve(RuuviServiceExport.self)
        presenter.configure(ruuviTag: ruuviTag)

        interactor.gattService = r.resolve(GATTService.self)
        interactor.settings = r.resolve(RuuviLocalSettings.self)
        interactor.exportService = r.resolve(RuuviServiceExport.self)
        interactor.ruuviReactor = r.resolve(RuuviReactor.self)
        interactor.ruuviPool = r.resolve(RuuviPool.self)
        interactor.ruuviStorage = r.resolve(RuuviStorage.self)
        interactor.ruuviSensorRecords = r.resolve(RuuviServiceSensorRecords.self)
        interactor.featureToggleService = r.resolve(FeatureToggleService.self)
        interactor.localSyncState = r.resolve(RuuviLocalSyncState.self)
        interactor.ruuviAppSettingsService = r.resolve(RuuviServiceAppSettings.self)
        interactor.presenter = presenter

        view.output = presenter
    }
}
