import UIKit

protocol VisibilitySettingsRouterInput: AnyObject {
    func dismiss()
}

final class VisibilitySettingsRouter: VisibilitySettingsRouterInput {
    weak var transitionHandler: UIViewController?

    func dismiss() {
        transitionHandler?
            .navigationController?
            .popViewController(animated: true)
    }
}
