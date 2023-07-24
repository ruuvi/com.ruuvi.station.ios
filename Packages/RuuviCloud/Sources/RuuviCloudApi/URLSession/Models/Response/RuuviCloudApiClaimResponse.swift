import Foundation

public struct RuuviCloudApiClaimResponse: Decodable {
    public let sensor: String?
}
public struct RuuviCloudApiClaimError: Decodable {
    public let error, code: String?
}
public struct RuuviCloudApiUnclaimResponse: Decodable {
}
