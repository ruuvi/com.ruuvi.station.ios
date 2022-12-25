import Foundation

public struct RuuviCloudPNTokenUnregisterRequest: Encodable {
    let token: String?
    let id: Int?
}
