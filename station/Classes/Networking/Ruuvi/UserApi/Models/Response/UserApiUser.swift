import Foundation

struct UserApiUserResponse: Decodable {
    let email: String
    let sensors: [UserApiUserSensor]
}

struct UserApiUserSensor: Decodable {
    let sensor: String
    let isOwner: Bool
    let pictureUrl: String

    enum CodingKeys: String, CodingKey {
        case sensor
        case isOwner = "owner"
        case pictureUrl = "picture"
    }
}
