import Foundation

extension Notification.Name {
    static let DidOpenWithUniversalLink = Notification.Name("DidOpenWithUniversalLink")
}

protocol UniversalLinkCoordinator: class {
    func processUniversalLink(url: URL)
}
