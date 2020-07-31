import Foundation
import Future

class AddMacModalPresenter {
    weak var view: AddMacModalViewInput!
    var output: AddMacModalModuleOutput!
    var router: AddMacModalRouterInput!

    private var viewModel: AddMacModalViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }
}
// MARK: - AddMacModalViewOutput
extension AddMacModalPresenter: AddMacModalViewOutput {
    func viewDidLoad() {
    }
}
// MARK: - AddMacModalModuleInput
extension AddMacModalPresenter: AddMacModalModuleInput {
    func configure(output: AddMacModalModuleOutput) {
        self.output = output
    }

    func dismiss() {
        router.dismiss(completion: nil)
    }
}
// MARK: - Private
extension AddMacModalPresenter {
}
