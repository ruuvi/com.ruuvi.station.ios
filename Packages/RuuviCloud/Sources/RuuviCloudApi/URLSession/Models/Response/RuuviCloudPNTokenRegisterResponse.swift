import Foundation

public struct RuuviCloudPNTokenRegisterResponse: Decodable {
    public let id: Int
    public let lastAccessed: Int?
    public let name: String?
}
