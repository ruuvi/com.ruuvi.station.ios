import Foundation
import MessageUI
import RuuviPresenters

class MailComposerPresenterMessageUI: NSObject, MailComposerPresenter {
    var canOpenURL: (URL) -> Bool = { UIApplication.shared.canOpenURL($0) }
    var openURL: (URL) -> Void = { UIApplication.shared.open($0) }
    var errorPresenter: ErrorPresenter!

    func present(email: String, subject: String, body: String?) {
        if let emailURL = generateEmailURL(email: email, subject: subject, body: body) {
            openURL(emailURL)
        } else {
            errorPresenter.present(error: CoreError.unableToSendEmail)
        }
    }

    func present(email: String) {
        if let emailURL = URL(string: email), canOpenURL(emailURL) {
            openURL(emailURL)
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
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body ?? "")
        ]
        guard let url = components.url, canOpenURL(url) else { return nil }
        return url
    }
}
