import Foundation

// swiftlint:disable:next type_name
public enum RuuviCloudPNTokenRegisterRequestParamsKey: String {
    case sound = "soundFile"
    case language = "language"
}

public struct RuuviCloudPNTokenRegisterRequest: Encodable {
    let token: String
    let type: String
    let name: String?
    let data: String?
    let params: [String: String]?

    public init(token: String,
                type: String,
                name: String? = nil,
                data: String? = nil,
                params: [String: String]? = nil) {
        self.token = token
        self.type = type
        self.name = name
        self.data = data
        self.params = params
    }
}
