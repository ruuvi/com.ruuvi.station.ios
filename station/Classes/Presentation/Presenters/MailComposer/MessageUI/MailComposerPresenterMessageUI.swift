import Foundation
import MessageUI
import RuuviPresenters

class MailComposerPresenterMessageUI: NSObject, MailComposerPresenter {
    var errorPresenter: ErrorPresenter!

    func present(email: String, subject: String, body: String?) {
        guard let viewController = UIApplication.shared.topViewController() else { return }
        // If default iOS Mail app is configured, open the mail composer
        // Otherwise open the default email client set by the user followed by checking whether gmail app
        let emailRecipient = String(format: "App Feedback <%@>".localized(), email)
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setSubject(subject)
            if let body = body {
                mail.setMessageBody(body, isHTML: false)
            }
            mail.setToRecipients([emailRecipient])
            viewController.present(mail, animated: true)
        } else if let emailURL = generateEmailURL(email: emailRecipient, subject: subject, body: body) {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(emailURL)
            } else {
                UIApplication.shared.openURL(emailURL)
            }
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

// MARK: - Private method
extension MailComposerPresenterMessageUI {
    /// This method takes three arguments recipient email, subject and body.
    /// Returns a computer email URL that opens the default email client set by the user.
    private func generateEmailURL(email: String, subject: String, body: String?) -> URL? {
        guard let toEncoded = email
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let subjectEncoded = subject
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        let bodyEncoded = body?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let defaultURL = URL(string: "mailto:\(toEncoded)?subject=\(subjectEncoded)&body=\(bodyEncoded)")
        if let defaultURL = defaultURL, UIApplication.shared.canOpenURL(defaultURL) {
            return defaultURL
        } else {
            return nil
        }
    }
}
