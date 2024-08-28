import Foundation
import MessageUI
import RuuviPresenters

class MailComposerPresenterMessageUI: NSObject, MailComposerPresenter {
    var errorPresenter: ErrorPresenter!

    func present(email: String, subject: String, body: String?) {
        if let emailURL = generateEmailURL(email: email, subject: subject, body: body) {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(emailURL)
            } else {
                UIApplication.shared.openURL(emailURL)
            }
        } else {
            errorPresenter.present(error: CoreError.unableToSendEmail)
        }
    }

    func present(email: String) {
        if let emailURL = URL(string: email), UIApplication.shared.canOpenURL(emailURL) {
            UIApplication.shared.open(emailURL)
        } else {
            errorPresenter.present(error: CoreError.unableToSendEmail)
        }
    }
}

// MARK: - MFMailComposeViewControllerDelegate

extension MailComposerPresenterMessageUI: MFMailComposeViewControllerDelegate {
    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith _: MFMailComposeResult,
        error _: Error?
    ) {
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
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            return nil
        }
        let bodyEncoded = body?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let defaultURL = URL(string: "mailto:\(toEncoded)?subject=\(subjectEncoded)&body=\(bodyEncoded)")
        if let defaultURL, UIApplication.shared.canOpenURL(defaultURL) {
            return defaultURL
        } else {
            return nil
        }
    }
}
