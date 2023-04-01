import Foundation
import RuuviCloud

public protocol UserApiUploadRequest: Codable {
    var sensor: String { get }
    var mimeType: MimeType? { get }
}
