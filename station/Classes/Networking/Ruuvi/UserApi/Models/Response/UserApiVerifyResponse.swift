import Foundation

struct UserApiVerifyResponse: Decodable {
    let email: String
    let accessToken: String
    let isNewUser: Bool

    enum CodingKeys: String, CodingKey {
        case email
        case accessToken
        case isNewUser = "newUser"
    }
}
