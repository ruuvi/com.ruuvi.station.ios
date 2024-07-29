import RuuviLocal
import RuuviUser
import UIKit

enum UniversalLinkType: String {
    case verify = "/verify"
    case dashboard = "/dashboard"

    var handlerType: UIViewController.Type {
        switch self {
        case .verify:
            SignInViewController.self
        case .dashboard:
            DashboardViewController.self
        }
    }
}

class UniversalLinkCoordinatorImpl {
    var ruuviUser: RuuviUser!
    var router: UniversalLinkRouter!
    var settings: RuuviLocalSettings!

    private var urlComponents: URLComponents!
}

// MARK: - UniversalLinkInteractorInput

extension UniversalLinkCoordinatorImpl: UniversalLinkCoordinator {
    func processUniversalLink(url: URL) {
        guard let urlComponents = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ),
            let path = UniversalLinkType(rawValue: urlComponents.path)
        else {
            return
        }
        self.urlComponents = urlComponents
        detectViewController(for: path)
    }

    func processWidgetLink(macId: String) {
        NotificationCenter.default.post(
            name: .DidOpenWithWidgetDeepLink,
            object: nil,
            userInfo: [WidgetDeepLinkMacIdKey.macId: macId]
        )
        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self else { return }
            guard let topViewController = UIApplication.shared.topViewController()
            else {
                return
            }
            sSelf.router
                .openSensorCard(
                    with: macId,
                    settings: sSelf.settings,
                    from: topViewController
                )
        }
    }
}

// MARK: - Private

extension UniversalLinkCoordinatorImpl {
    private func detectViewController(for path: UniversalLinkType) {
        DispatchQueue.main.async { [weak self] in
            guard let topViewController = UIApplication.shared.topViewController()
            else {
                return
            }
            if topViewController.isMember(of: path.handlerType) {
                self?.postNotification(with: path)
            } else {
                switch path {
                case .verify:
                    self?.openVerify(from: topViewController)
                case .dashboard:
                    self?.openDashboard(from: topViewController)
                }
            }
        }
    }

    private func openVerify(from topViewController: UIViewController) {
        guard let token = urlComponents.queryItems?
            .first(where: { $0.name == "token" })?
            .value,
            !ruuviUser.isAuthorized
        else {
            NotificationCenter.default.post(
                name: .DidOpenWithUniversalLink,
                object: nil,
                userInfo: nil
            )
            return
        }
        router.openSignInVerify(with: token, from: topViewController)
    }

    private func openDashboard(from _: UIViewController) {
        // No action needed here since root view controller is dashboard, and
        // we will be opening dashboard anyway on deeplink tap.
    }

    private func postNotification(with path: UniversalLinkType) {
        var userInfo: [String: Any] = [
            "path": path
        ]
        urlComponents.queryItems?.forEach {
            userInfo[$0.name] = $0.value
        }
        NotificationCenter.default.post(
            name: .DidOpenWithUniversalLink,
            object: nil,
            userInfo: userInfo
        )
    }
}
