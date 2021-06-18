import Foundation
import RuuviCloud

public struct RuuviCloudApiSensorImageUploadRequest: UserApiUploadRequest {
    public let sensor: String
    public let action: UploadAction
    public let mimeType: MimeType?

    public init(
        sensor: String,
        action: UploadAction
    ) {
        self.sensor = sensor
        self.action = action
        self.mimeType = nil
    }

    public init(
        sensor: String,
        action: UploadAction,
        mimeType: MimeType
    ) {
        self.sensor = sensor
        self.action = action
        self.mimeType = mimeType
    }

    public enum UploadAction: String, Encodable {
        case upload
        case reset
    }

    enum CodingKeys: String, CodingKey {
        case sensor
        case action
        case mimeType = "type"
    }
}
