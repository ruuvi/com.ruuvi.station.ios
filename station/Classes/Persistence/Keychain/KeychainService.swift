protocol KeychainService {
    var kaltiotApiKey: String? { get set }
    var hasKaltiotApiKey: Bool { get }
    var ruuviUserApiKey: String? { get set }
}
extension KeychainService {
    var hasKaltiotApiKey: Bool {
        return !((kaltiotApiKey ?? "").isEmpty)
    }

    var userApiIsAuthorized: Bool {
        return !((ruuviUserApiKey ?? "").isEmpty)
    }
}
