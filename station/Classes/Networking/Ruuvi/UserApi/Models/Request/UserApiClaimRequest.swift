import Foundation

struct UserApiClaimRequest: Encodable {
    let name: String?
    let sensor: String
}
