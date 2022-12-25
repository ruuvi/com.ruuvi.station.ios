import Foundation

public struct RuuviCloudPNTokenRegisterRequest: Encodable {
    let token: String
    let type: String
    let name: String?
    let data: String?

    public init(token: String,
                type: String,
                name: String? = nil,
                data: String? = nil) {
        self.token = token
        self.type = type
        self.name = name
        self.data = data
    }
}
