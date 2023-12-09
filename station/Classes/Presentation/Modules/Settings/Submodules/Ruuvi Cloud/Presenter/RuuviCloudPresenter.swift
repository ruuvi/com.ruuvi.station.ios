import Foundation
import RuuviLocal
import RuuviLocalization
import RuuviService
import UIKit

class RuuviCloudPresenter: NSObject, RuuviCloudModuleInput {
    var viewController: UIViewController {
        if let view = weakView {
            return view
        } else {
            let view = RuuviCloudTableViewController()
            view.output = self
            weakView = view
            return view
        }
    }

    private weak var weakView: UIViewController?

    var settings: RuuviLocalSettings!
    var ruuviAppSettingsService: RuuviServiceAppSettings!
}

extension RuuviCloudPresenter: RuuviCloudViewOutput {
    func viewDidLoad() {
        // No op here.
    }

    func viewWillAppear() {
        configure()
    }
}

private extension RuuviCloudPresenter {
    func configure() {
        if let view = weakView as? RuuviCloudTableViewController {
            view.viewModels = [ruuviCloudIsOn()]
        }
    }

    func ruuviCloudIsOn() -> RuuviCloudViewModel {
        let cloudMode = RuuviCloudViewModel()
        cloudMode.title = RuuviLocalization.Settings.Label.cloudMode
        cloudMode.boolean.value = settings.cloudModeEnabled
        bind(cloudMode.boolean, fire: false) { observer, isOn in
            observer.settings.cloudModeEnabled = isOn.bound
            observer.ruuviAppSettingsService.set(cloudMode: isOn.bound)
        }
        return cloudMode
    }
}
