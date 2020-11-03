protocol KeychainService {
    var ruuviUserApiKey: String? { get set }
    var userApiEmail: String? { get set }
}
extension KeychainService {

    var userApiIsAuthorized: Bool {
        return !((ruuviUserApiKey ?? "").isEmpty)
            && !((userApiEmail ?? "").isEmpty)
    }

    mutating func userApiLogOut() {
        ruuviUserApiKey = nil
        userApiEmail = nil
    }
}
