import UIKit
extension Notification.Name {
    static let UserDidLogOut = Notification.Name("KeychainService.UserDidLogOut")
}

protocol KeychainService {
    var ruuviUserApiKey: String? { get set }
    var userApiEmail: String? { get set }
}
extension KeychainService {

    var userIsAuthorized: Bool {
        return !((ruuviUserApiKey ?? "").isEmpty)
            && !((userApiEmail ?? "").isEmpty)
    }

    mutating func userApiLogOut() {
        ruuviUserApiKey = nil
        userApiEmail = nil
        NotificationCenter
            .default
            .post(name: .UserDidLogOut,
                  object: self,
                  userInfo: nil)
    }
}
