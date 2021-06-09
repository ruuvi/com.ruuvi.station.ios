import Foundation

class DfuFlashConfigurator: NSObject {
    func configure(view: DfuFlashAppleViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = DfuFlashRouter()
        router.transitionHandler = view

        let presenter = DfuFlashPresenter()
        presenter.view = view
        view.delegate = presenter
        presenter.router = router
        presenter.filePresener = r.resolve(DfuFilePickerPresenter.self)
        presenter.ruuviDfu = r.resolve(RuuviDfu.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)

        view.output = presenter
    }
}
