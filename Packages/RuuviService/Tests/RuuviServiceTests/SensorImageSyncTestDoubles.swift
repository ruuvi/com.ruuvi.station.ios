@testable import RuuviLocal
import RuuviOntology
import RuuviCore
import Future
import UIKit

final class SyncImageDisk: ImagePersistence {
    var images: [String: UIImage] = [:]
    var heldWrite: Promise<URL, RuuviLocalError>?
    var imageDecodes = 0
    var dataReadOnMain: Bool?
    func hasBg(for identifier: Identifier) -> Bool { images[identifier.value] != nil }
    func fetchBgData(for identifier: Identifier) throws -> Data {
        dataReadOnMain = Thread.isMainThread
        guard let data = fetchBg(for: identifier)?.jpegData(compressionQuality: 1) else {
            throw RuuviLocalError.failedToGetJpegRepresentation
        }
        return data
    }
    func fetchBg(for identifier: Identifier) -> UIImage? {
        imageDecodes += 1
        return images[identifier.value]
    }
    func deleteBgIfExists(for identifier: Identifier) { images.removeValue(forKey: identifier.value) }
    func persistBg(image: UIImage, compressionQuality: CGFloat, for identifier: Identifier)
    -> Future<URL, RuuviLocalError> {
        images[identifier.value] = image
        if let heldWrite { return heldWrite.future }
        let result = Promise<URL, RuuviLocalError>()
        result.succeed(value: URL(fileURLWithPath: "/tmp/test-image.jpg"))
        return result.future
    }
}

struct SyncCoreImage: RuuviCoreImage {
    func cropped(image: UIImage, to maxSize: CGSize) -> UIImage { image }
}
