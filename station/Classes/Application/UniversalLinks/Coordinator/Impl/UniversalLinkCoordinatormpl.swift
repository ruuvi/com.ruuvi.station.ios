import UIKit
import RuuviUser

enum UniversalLinkType: String {
    case verify = "/verify"

    var handlerType: UIViewController.Type {
        switch self {
        case .verify:
            return SignInViewController.self
        }
    }
}

class UniversalLinkCoordinatorImpl {
    var ruuviUser: RuuviUser!
    var router: UniversalLinkRouter!

    private var urlComponents: URLComponents!
}
// MARK: - UniversalLinkInteractorInput

extension UniversalLinkCoordinatorImpl: UniversalLinkCoordinator {
    func processUniversalLink(url: URL) {
        guard let urlComponents = URLComponents(url: url,
                                                resolvingAgainstBaseURL: false),
              let path = UniversalLinkType(rawValue: urlComponents.path) else {
            return
        }
        self.urlComponents = urlComponents
        detectViewController(for: path)
    }
}

// MARK: - Private

extension UniversalLinkCoordinatorImpl {

    private func detectViewController(for path: UniversalLinkType) {
        DispatchQueue.main.async { [weak self] in
            guard let topViewController = UIApplication.shared.topViewController() else {
                return
            }
            if topViewController.isMember(of: path.handlerType) {
                self?.postNotification(with: path)
            } else {
                switch path {
                case .verify:
                    self?.openVerify(from: topViewController)
                }
            }
        }
    }

    private func openVerify(from topViewController: UIViewController) {
        guard let token = urlComponents.queryItems?
                .first(where: { $0.name == "token" })?
                .value,
              !ruuviUser.isAuthorized else {
                  NotificationCenter.default.post(name: .DidOpenWithUniversalLink,
                                                  object: nil,
                                                  userInfo: nil)
            return
        }
        router.openSignInVerify(with: token, from: topViewController)
    }

    private func postNotification(with path: UniversalLinkType) {
        var userInfo: [String: Any] = [
            "path": path
        ]
        urlComponents.queryItems?.forEach({
            userInfo[$0.name] = $0.value
        })
        NotificationCenter.default.post(name: .DidOpenWithUniversalLink,
                                        object: nil,
                                        userInfo: userInfo)
    }
}
