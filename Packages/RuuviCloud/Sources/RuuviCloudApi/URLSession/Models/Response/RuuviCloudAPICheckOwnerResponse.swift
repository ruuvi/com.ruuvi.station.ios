import Foundation

public struct RuuviCloudAPICheckOwnerResponse: Decodable {
    public let email: String?
    public let sensor: String?
}
