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
    let temperatureOffset: Double? // in degrees
    let humidityOffset: Double? // in percents
    let pressureOffset: Double? // in Pa

    enum CodingKeys: String, CodingKey {
        case sensorId = "sensor"
        case sensorOwner = "owner"
        case name
        case pictureUrl = "picture"
        case isPublic = "public"
        case temperatureOffset = "offsetTemperature"
        case humidityOffset = "offsetHumidity"
        case pressureOffset = "offsetPressure"
    }
}

extension RuuviCloudApiSensor: CloudSensor {
    var offsetTemperature: Double? {
        return temperatureOffset
    }

    // on cloud in percent, locally in fraction of one
    var offsetHumidity: Double? {
        if let humidityOffset = humidityOffset {
            return humidityOffset / 100.0
        } else {
            return nil
        }
    }

    // on cloud in Pa, locally in hPa
    var offsetPressure: Double? {
        if let pressureOffset = pressureOffset {
            return pressureOffset / 100.0
        } else {
            return nil
        }
    }

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
