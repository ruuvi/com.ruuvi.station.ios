protocol KeychainService {
    var kaltiotApiKey: String? { get set }
    var hasKaltiotApiKey: Bool { get }
    var ruuviNetworkApiKey: String? { get set }
}
extension KeychainService {
    var hasKaltiotApiKey: Bool {
        return !((kaltiotApiKey ?? "").isEmpty)
    }
}
