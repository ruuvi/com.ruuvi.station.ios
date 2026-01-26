import Foundation
import RuuviLocal
import RuuviPresenters
import RuuviService

protocol SensorRemovalModuleFactory {
    func create() -> SensorRemovalViewController
}

final class SensorRemovalModuleFactoryImpl: SensorRemovalModuleFactory {
    func create() -> SensorRemovalViewController {
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
    private func buildModule() -> SensorRemovalViewController {
        let r = AppAssembly.shared.assembler.resolver

        let view = SensorRemovalViewController()
        let router = SensorRemovalRouter()
        router.transitionHandler = view

        let presenter = SensorRemovalPresenter()
        presenter.view = view
        presenter.router = router
        presenter.ruuviOwnershipService = r.resolve(RuuviServiceOwnership.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)

        view.output = presenter

        return view
    }
}
