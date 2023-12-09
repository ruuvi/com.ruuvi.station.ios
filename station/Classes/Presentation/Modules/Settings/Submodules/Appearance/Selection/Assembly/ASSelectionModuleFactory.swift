import RuuviLocal
import UIKit

protocol ASSelectionModuleFactory {
    func create(with title: String) -> ASSelectionTableViewController
}

final class ASSelectionModuleFactoryImpl: ASSelectionModuleFactory {
    func create(with title: String) -> ASSelectionTableViewController {
        let r = AppAssembly.shared.assembler.resolver

        let view = ASSelectionTableViewController(
            title: title
        )

        let presenter = ASSelectionPresenter()
        presenter.view = view
        presenter.settings = r.resolve(RuuviLocalSettings.self)

        view.output = presenter
        return view
    }
}
