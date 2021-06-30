import Foundation
import RuuviCloud

public protocol UserApiUploadRequest: Encodable {
    var sensor: String { get }
    var mimeType: MimeType? { get }
}
