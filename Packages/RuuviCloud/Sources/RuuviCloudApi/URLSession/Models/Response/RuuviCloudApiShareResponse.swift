import Foundation

public struct RuuviCloudApiShareResponse: Decodable {
    public let sensor: String?
    public let invited: Bool?
}
