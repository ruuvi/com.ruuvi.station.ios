import Foundation

protocol MailComposerPresenter {
    func present(email: String, subject: String, body: String?)
}

extension MailComposerPresenter {
    func present(email: String, subject: String) {
        return present(email: email, subject: subject, body: nil)
    }
}
