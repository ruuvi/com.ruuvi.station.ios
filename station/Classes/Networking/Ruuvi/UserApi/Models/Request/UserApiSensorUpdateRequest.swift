import Foundation

struct UserApiSensorUpdateRequest: Encodable {
    let sensor: String
    let name: String
}
