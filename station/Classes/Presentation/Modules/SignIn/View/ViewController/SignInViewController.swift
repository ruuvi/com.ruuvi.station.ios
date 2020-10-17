import UIKit

class SignInViewController: UIViewController {
    var output: SignInViewOutput!
    var viewModel: SignInViewModel!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        output.viewDidLoad()
    }
}

// MARK: - SignInViewInput
extension SignInViewController: SignInViewInput {
    func localize() {
        title = "SignIn.Title.text".localized()
    }
}

// MARK: - Private
extension SignInViewController {
}
