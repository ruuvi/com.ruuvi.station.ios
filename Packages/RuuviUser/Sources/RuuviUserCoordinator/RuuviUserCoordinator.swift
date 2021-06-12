import Foundation

final class RuuviUserCoordinator: RuuviUser {
    var apiKey: String? {
        get {
            return keychainService.ruuviUserApiKey
        }
        set {
            keychainService.ruuviUserApiKey = newValue
        }
    }
    var email: String? {
        get {
            return keychainService.userApiEmail
        }
        set {
            keychainService.userApiEmail = newValue
        }
    }
    var isAuthorized: Bool {
        return !((email ?? "").isEmpty)
            && !((apiKey ?? "").isEmpty)
    }

    private var keychainService: KeychainService

    init(keychainService: KeychainService) {
        self.keychainService = keychainService
    }

    func login(apiKey: String) {
        self.apiKey = apiKey
    }

    func logout() {
        email = nil
        apiKey = nil
    }
}
