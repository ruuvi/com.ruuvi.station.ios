import Foundation
import RuuviOntology

struct RuuviCloudApiUserResponse: Decodable {
    let email: String
    var sensors: [RuuviCloudApiSensor]
}

struct RuuviCloudApiSensor: Decodable {
    let sensorId: String
    let sensorOwner: String
    let pictureUrl: String
    let name: String
    let isPublic: Bool
    var isOwner: Bool = false

    enum CodingKeys: String, CodingKey {
        case sensorId = "sensor"
        case sensorOwner = "owner"
        case name
        case pictureUrl = "picture"
        case isPublic = "public"
    }
}

extension RuuviCloudApiSensor: CloudSensor {
    var picture: URL? {
        return URL(string: pictureUrl)
    }

    var owner: String? {
        return sensorOwner
    }

    var isClaimed: Bool {
        return isOwner
    }

    var id: String {
        return sensorId
    }
}
