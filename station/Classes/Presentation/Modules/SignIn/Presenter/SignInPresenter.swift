import Foundation
import Future

class SignInPresenter {
    weak var view: SignInViewInput!
    var output: SignInModuleOutput!
    var router: SignInRouterInput!

    private var viewModel: SignInViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }
}
// MARK: - SignInViewOutput
extension SignInPresenter: SignInViewOutput {
    func viewDidLoad() {
    }
}
// MARK: - SignInModuleInput
extension SignInPresenter: SignInModuleInput {
    func configure(output: SignInModuleOutput) {
        self.output = output
    }

    func dismiss() {
        router.dismiss(completion: nil)
    }
}
// MARK: - Private
extension SignInPresenter {
}
