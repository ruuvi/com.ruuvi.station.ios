import Foundation

public struct RuuviCloudPNTokenUnregisterRequest: Encodable {
    let token: String?
    let id: Int?
    
    public init(token: String?, id: Int?) {
        self.token = token
        self.id = id
    }
}
