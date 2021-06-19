import Foundation

public struct RuuviCloudApiRegisterRequest: Encodable {
    let email: String

    public init(email: String) {
        self.email = email
    }
}
