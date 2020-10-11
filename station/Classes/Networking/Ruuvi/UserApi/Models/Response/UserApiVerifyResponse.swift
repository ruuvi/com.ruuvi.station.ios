import Foundation

struct UserApiVerifyResponse: Decodable {
    let email: String
    let accessToken: String
    let isNewUser: Bool

    enum CodingKeys: String, CodingKey {
        case email
        case accessToken = "access_token"
        case isNewUser = "new_user"
    }
}
