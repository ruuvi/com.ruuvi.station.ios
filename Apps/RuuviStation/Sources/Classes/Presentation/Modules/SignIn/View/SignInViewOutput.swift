import Foundation

protocol SignInViewOutput {
    func viewDidLoad()
    func viewDidTapBack()
    func viewDidTapRequestCodeButton(for email: String?)
    func viewDidTapEnterCodeManually(code: String)
    func viewDidTapUseWithoutAccount()
}
