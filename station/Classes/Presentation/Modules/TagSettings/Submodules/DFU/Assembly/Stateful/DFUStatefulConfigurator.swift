import Foundation

class DFUStatefulConfigurator: NSObject {
    func configure(view: DFUStatefulViewController) {
        let r = AppAssembly.shared.assembler.resolver
        let interactor = DFUInteractor()

        let presenter = DFUPresenter()
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.view = view
        presenter.interactor = interactor

        view.output = presenter
    }
}
