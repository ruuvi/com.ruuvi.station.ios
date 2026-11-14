import Foundation

public struct RuuviCloudApiVerifyRequest: Encodable {
    var token: String
    var email: String
    public init(token: String, email: String) {
        self.token = token
        self.email = email
    }
}
