import Foundation

struct UserApiSensorImageUploadRequest: Encodable {
    let sensor: String
    let mimeType: MimeType

    enum CodingKeys: String, CodingKey {
        case sensor
        case mimeType = "type"
    }

    enum MimeType: String, Encodable {
        case png = "image/png"
        case gif = "image/gif"
        case jpg = "image/jpg"
    }
}
