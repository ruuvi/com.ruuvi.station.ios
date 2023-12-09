import Foundation

public protocol UserApiUploadRequest: Codable {
    var sensor: String { get }
    var mimeType: MimeType? { get }
}
