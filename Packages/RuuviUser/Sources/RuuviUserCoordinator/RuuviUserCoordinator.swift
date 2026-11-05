#if SWIFT_PACKAGE
    import RuuviUser
#endif
import Foundation

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
            keychainService.userIsAuthorized && defaults.bool(forKey: isAuthorizedUDKey)
        }
        set {
            defaults.set(newValue, forKey: isAuthorizedUDKey)
            appGroupDefaults?.set(newValue, forKey: isAuthorizedUDKey)
        }
    }

    private var keychainService: KeychainService
    private let isAuthorizedUDKey = "RuuviUserCoordinator.isAuthorizedUDKey"
    private let defaults: UserDefaults
    private let appGroupDefaults: UserDefaults?
    private let notificationCenter: NotificationCenter

    init(
        keychainService: KeychainService,
        defaults: UserDefaults = .standard,
        appGroupDefaults: UserDefaults? = UserDefaults(suiteName: "group.com.ruuvi.station.widgets"),
        notificationCenter: NotificationCenter = .default
    ) {
        self.keychainService = keychainService
        self.defaults = defaults
        self.appGroupDefaults = appGroupDefaults
        self.notificationCenter = notificationCenter
    }

    func login(apiKey: String) {
        self.apiKey = apiKey
        guard !apiKey.isEmpty, keychainService.ruuviUserApiKey == apiKey else {
            isAuthorized = false
            return
        }
        isAuthorized = true
        notificationCenter.post(
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
