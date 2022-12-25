import Foundation
import UIKit
import RuuviService
import RuuviLocal

class RuuviCloudPresenter: NSObject, RuuviCloudModuleInput {
    var viewController: UIViewController {
        if let view = self.weakView {
            return view
        } else {
            let view = RuuviCloudTableViewController()
            view.output = self
            self.weakView = view
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

extension RuuviCloudPresenter {
    fileprivate func configure() {
        if let view = weakView as? RuuviCloudTableViewController {
            view.viewModels = [ruuviCloudIsOn()]
        }
    }

    fileprivate func ruuviCloudIsOn() -> RuuviCloudViewModel {
        let cloudMode = RuuviCloudViewModel()
        cloudMode.title = "Settings.Label.CloudMode".localized()
        cloudMode.boolean.value = settings.cloudModeEnabled
        bind(cloudMode.boolean, fire: false) { observer, isOn in
            observer.settings.cloudModeEnabled = isOn.bound
            observer.ruuviAppSettingsService.set(cloudMode: isOn.bound)
        }
        return cloudMode
    }
}
