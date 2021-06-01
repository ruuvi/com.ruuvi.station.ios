import Foundation

struct RuuviCloudApiSensorImageUploadRequest: UserApiUploadRequest {
    let sensor: String
    let action: UploadAction
    let mimeType: MimeType?

    init(
        sensor: String,
        action: UploadAction
    ) {
        self.sensor = sensor
        self.action = action
        self.mimeType = nil
    }

    init(
        sensor: String,
        action: UploadAction,
        mimeType: MimeType
    ) {
        self.sensor = sensor
        self.action = action
        self.mimeType = mimeType
    }

    enum UploadAction: String, Encodable {
        case upload
        case reset
    }

    enum CodingKeys: String, CodingKey {
        case sensor
        case action
        case mimeType = "type"
    }
}
