import Foundation

protocol SignInViewInput: ViewInput {
    var viewModel: SignInViewModel! { get set }
    var fromDeepLink: Bool { get set }
    func showEmailsAreDifferent(
        requestedEmail: String,
        validatedEmail: String
    )
    func showFailedToGetRequestedEmail()
    func showInvalidTokenEntered()
    func showInvalidEmailEntered()
    func showUnexpectedHTTPStatusCodeError()
}
