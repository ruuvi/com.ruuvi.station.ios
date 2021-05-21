import Foundation

extension Notification.Name {
    static let DidOpenWithUniversalLink = Notification.Name("DidOpenWithUniversalLink")
}

protocol UniversalLinkCoordinator: AnyObject {
    func processUniversalLink(url: URL)
}
