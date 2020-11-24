import Foundation

struct UserApiUserResponse: Decodable {
    let email: String
    let sensors: [UserApiUserSensor]
}

struct UserApiUserSensor: Decodable {
    let sensorId: String
    let isOwner: Bool
    let pictureUrl: String
    let name: String
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case sensorId = "sensor"
        case isOwner = "owner"
        case name
        case pictureUrl = "picture"
        case isPublic = "public"
    }
}
