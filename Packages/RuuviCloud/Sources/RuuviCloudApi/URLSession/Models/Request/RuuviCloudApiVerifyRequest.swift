import Foundation

public struct RuuviCloudApiVerifyRequest: Encodable {
    var token: String
    public init(token: String) {
        self.token = token
    }
}
