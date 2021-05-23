import Foundation

protocol UserApiUploadRequest: Encodable {
    var sensor: String { get }
    var mimeType: MimeType { get }
}

enum MimeType: String, Encodable {
    case png = "image/png"
    case gif = "image/gif"
    case jpg = "image/jpg"
}
