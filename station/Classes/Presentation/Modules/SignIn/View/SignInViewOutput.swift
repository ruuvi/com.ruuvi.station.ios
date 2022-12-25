import Foundation

protocol SignInViewOutput {
    func viewDidLoad()
    func viewDidClose()
    func viewDidTapRequestCodeButton(for email: String?)
    func viewDidTapEnterCodeManually(code: String)
    func viewDidTapUseWithoutAccount()
}
