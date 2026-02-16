import Foundation
import RuuviCloud
import RuuviCore
import RuuviLocal
import RuuviPresenters
import RuuviService
import RuuviUser

class MyRuuviAccountConfigurator {
    func configure(view: MyRuuviAccountViewController) {
        let r = AppAssembly.shared.assembler.resolver
        let router = MyRuuviAccountRouter()
        router.transitionHandler = view

        let presenter = MyRuuviAccountPresenter()
        presenter.view = view
        presenter.router = router
        presenter.ruuviCloud = r.resolve(RuuviCloud.self)
        presenter.ruuviUser = r.resolve(RuuviUser.self)
        presenter.alertPresenter = r.resolve(AlertPresenter.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.authService = r.resolve(RuuviServiceAuth.self)
        presenter.pnManager = r.resolve(RuuviCorePN.self)
        presenter.cloudNotificationService = r.resolve(RuuviServiceCloudNotification.self)
        presenter.ruuviAppSettingsService = r.resolve(RuuviServiceAppSettings.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.mailComposerPresenter = r.resolve(MailComposerPresenter.self)
        view.output = presenter
    }
}
