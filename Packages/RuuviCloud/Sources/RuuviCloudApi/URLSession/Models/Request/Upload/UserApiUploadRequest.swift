import Foundation

protocol UserApiUploadRequest: Encodable {
    var sensor: String { get }
    var mimeType: MimeType { get }
}
