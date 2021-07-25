import Foundation
import MessageUI
import RuuviPresenters

class MailComposerPresenterMessageUI: NSObject, MailComposerPresenter {
    var errorPresenter: ErrorPresenter!

    func present(email: String, subject: String, body: String?) {
        guard let viewController = UIApplication.shared.topViewController() else { return }
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setSubject(subject)
            if let body = body {
                mail.setMessageBody(body, isHTML: true)
            }
            mail.setToRecipients([String(format: "App Feedback <%@>".localized(), email)])
            viewController.present(mail, animated: true)
        } else {
            errorPresenter.present(error: CoreError.unableToSendEmail)
        }
    }
}

// MARK: - MFMailComposeViewControllerDelegate
extension MailComposerPresenterMessageUI: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {
        controller.dismiss(animated: true)
    }
}
