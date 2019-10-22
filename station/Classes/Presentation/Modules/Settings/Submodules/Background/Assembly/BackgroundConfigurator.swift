import Foundation
import BTKit

class BackgroundConfigurator {
    func configure(view: BackgroundViewController) {
        let r = AppAssembly.shared.assembler.resolver
        
        let router = BackgroundRouter()
        router.transitionHandler = view
        
        let presenter = BackgroundPresenter()
        presenter.view = view
        presenter.router = router
        presenter.scanner = r.resolve(BTScanner.self)
        
        view.output = presenter
    }
}
