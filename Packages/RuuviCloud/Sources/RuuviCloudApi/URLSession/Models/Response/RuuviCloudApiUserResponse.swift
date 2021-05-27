import Foundation

struct RuuviCloudApiUserResponse: Decodable {
    let email: String
    var sensors: [RuuviCloudApiSensor]
}

struct RuuviCloudApiSensor: Decodable {
    let sensorId: String
    let owner: String
    let pictureUrl: String
    let name: String
    let isPublic: Bool
    var isOwner: Bool = false

    enum CodingKeys: String, CodingKey {
        case sensorId = "sensor"
        case owner
        case name
        case pictureUrl = "picture"
        case isPublic = "public"
    }
}
