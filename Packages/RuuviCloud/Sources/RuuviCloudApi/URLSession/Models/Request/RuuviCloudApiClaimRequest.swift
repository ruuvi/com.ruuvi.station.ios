import Foundation

struct RuuviCloudApiClaimRequest: Encodable {
    let name: String?
    let sensor: String
}
