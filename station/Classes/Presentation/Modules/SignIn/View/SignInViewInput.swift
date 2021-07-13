import Foundation

protocol SignInViewInput: ViewInput {
    var viewModel: SignInViewModel! { get set }
    func updateTextFieldText()
    func showEmailsAreDifferent(requestedEmail: String, validatedEmail: String)
    func showFailedToGetRequestedEmail()
}
