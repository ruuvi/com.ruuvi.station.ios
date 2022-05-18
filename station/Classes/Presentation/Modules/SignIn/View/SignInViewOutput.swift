import Foundation

protocol SignInViewOutput {
    func viewDidLoad()
    func viewDidClose()
    func viewDidTapSubmitButton()
    func viewDidTapEnterCodeManually(code: String)
}
