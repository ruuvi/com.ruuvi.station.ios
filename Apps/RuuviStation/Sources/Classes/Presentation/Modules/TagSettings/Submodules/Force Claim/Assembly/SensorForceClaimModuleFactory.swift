import BTKit
import Foundation
import RuuviDFU
import RuuviLocal
import RuuviPool
import RuuviPresenters
import RuuviService
import RuuviUser

protocol SensorForceClaimModuleFactory {
    func create() -> SensorForceClaimViewController
}

final class SensorForceClaimModuleFactoryImpl: SensorForceClaimModuleFactory {
    func create() -> SensorForceClaimViewController {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                buildModule()
            }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                buildModule()
            }
        }
    }

    @MainActor
    private func buildModule() -> SensorForceClaimViewController {
        let r = AppAssembly.shared.assembler.resolver

        let view = SensorForceClaimViewController()
        let router = SensorForceClaimRouter()
        router.transitionHandler = view

        let presenter = SensorForceClaimPresenter()
        presenter.view = view
        presenter.router = router
        presenter.ruuviOwnershipService = r.resolve(RuuviServiceOwnership.self)
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.ruuviUser = r.resolve(RuuviUser.self)
        presenter.ruuviPool = r.resolve(RuuviPool.self)
        presenter.background = r.resolve(BTBackground.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)

        view.output = presenter

        return view
    }
}
