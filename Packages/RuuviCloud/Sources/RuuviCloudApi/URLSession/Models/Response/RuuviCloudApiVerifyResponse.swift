import Foundation

public struct RuuviCloudApiVerifyResponse: Decodable {
    public let email: String?
    public let accessToken: String?
    public let isNewUser: Bool?

    enum CodingKeys: String, CodingKey {
        case email
        case accessToken
        case isNewUser = "newUser"
    }
}
