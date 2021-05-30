import Foundation

struct RuuviCloudApiSensorImageUploadRequest: UserApiUploadRequest {
    let sensor: String
    let mimeType: MimeType

    enum CodingKeys: String, CodingKey {
        case sensor
        case mimeType = "type"
    }
}
