import Foundation

final class OwnerPresenter: OwnerModuleInput {
    weak var view: OwnerViewInput!
    var router: OwnerRouterInput!
}

extension OwnerPresenter: OwnerViewOutput {
    func viewDidTapOnClaim() {

    }
}
