import Foundation

extension Notification.Name {
    static let DidOpenWithUniversalLink = Notification.Name("DidOpenWithUniversalLink")
    static let DidOpenWithWidgetDeepLink = Notification.Name("DidOpenWithWidgetDeepLink")
}

public enum WidgetDeepLinkMacIdKey: String {
    case macId = "mac"
}

protocol UniversalLinkCoordinator: AnyObject {
    func processUniversalLink(url: URL)
}
