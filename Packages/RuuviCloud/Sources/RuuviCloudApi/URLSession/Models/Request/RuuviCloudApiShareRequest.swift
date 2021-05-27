import Foundation

struct RuuviCloudApiShareRequest: Encodable {
    let user: String?
    let sensor: String
}
