import RuuviLocal
import UIKit

protocol PushAlertSoundSelectionModuleFactory {
    func create(with title: String) -> PushAlertSoundSelectionTableViewController
}

final class PushAlertSoundSelectionModuleFactoryImpl: PushAlertSoundSelectionModuleFactory {
    func create(with title: String) -> PushAlertSoundSelectionTableViewController {
        let r = AppAssembly.shared.assembler.resolver

        let view = PushAlertSoundSelectionTableViewController(
            title: title
        )

        let presenter = PushAlertSoundSelectionPresenter()
        presenter.view = view
        presenter.settings = r.resolve(RuuviLocalSettings.self)

        view.output = presenter
        return view
    }
}
