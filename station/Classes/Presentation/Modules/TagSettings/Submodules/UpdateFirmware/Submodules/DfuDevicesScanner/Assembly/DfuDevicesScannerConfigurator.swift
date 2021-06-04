import Foundation
import BTKit

class DfuDevicesScannerConfigurator: NSObject {
    func configure(view: DfuDevicesScannerTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = DfuDevicesScannerRouter()
        router.transitionHandler = view

        let presenter = DfuDevicesScannerPresenter()
        presenter.view = view
        presenter.router = router
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.ruuviDfu = r.resolve(RuuviDfu.self)

        view.output = presenter
    }
}
