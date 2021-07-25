import Foundation

protocol KeychainService {
    var ruuviUserApiKey: String? { get set }
    var userApiEmail: String? { get set }
    var userIsAuthorized: Bool { get }
}
