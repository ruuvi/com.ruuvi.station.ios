import Foundation

public struct RuuviCloudApiAccountDeleteRequest: Encodable {
    var email: String
    public init(email: String) {
        self.email = email
    }
}
