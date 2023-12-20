import Foundation

protocol MailComposerPresenter {
    func present(email: String, subject: String, body: String?)
}

extension MailComposerPresenter {
    func present(email: String, subject: String) {
        present(email: email, subject: subject, body: nil)
    }
}
