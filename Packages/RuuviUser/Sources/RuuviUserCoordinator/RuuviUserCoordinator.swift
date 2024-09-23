import Foundation
import WidgetKit

final class RuuviUserCoordinator: RuuviUser {
    var apiKey: String? {
        get {
            keychainService.ruuviUserApiKey
        }
        set {
            keychainService.ruuviUserApiKey = newValue
        }
    }

    var email: String? {
        get {
            keychainService.userApiEmail?.lowercased()
        }
        set {
            keychainService.userApiEmail = newValue?.lowercased()
        }
    }

    var isAuthorized: Bool {
        get {
            UserDefaults.standard.bool(forKey: isAuthorizedUDKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: isAuthorizedUDKey)
            appGroupDefaults?.set(newValue, forKey: isAuthorizedUDKey)
        }
    }

    private var keychainService: KeychainService
    private let isAuthorizedUDKey = "RuuviUserCoordinator.isAuthorizedUDKey"
    private let appGroupDefaults = UserDefaults(suiteName: "group.com.ruuvi.station.widgets")

    init(keychainService: KeychainService) {
        self.keychainService = keychainService
    }

    func login(apiKey: String) {
        self.apiKey = apiKey
        isAuthorized = true
        NotificationCenter
            .default
            .post(
                name: .RuuviUserDidAuthorized,
                object: self,
                userInfo: nil
            )
    }

    func logout() {
        email = nil
        apiKey = nil
        isAuthorized = false
    }
}
