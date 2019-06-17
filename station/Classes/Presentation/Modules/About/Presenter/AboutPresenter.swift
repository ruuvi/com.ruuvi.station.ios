import Foundation

class AboutPresenter: AboutModuleInput {
    weak var view: AboutViewInput!
    var router: AboutRouterInput!
}

extension AboutPresenter: AboutViewOutput {
    func viewDidTriggerClose() {
        router.dismiss()
    }
}
