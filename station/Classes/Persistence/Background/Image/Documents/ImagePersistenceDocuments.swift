import UIKit
import Future

class ImagePersistenceDocuments: ImagePersistence {

    private let ext = ".png"
    private let bgDir = "bg"
    private var isBgDirCreated = false

    func fetchBg(for luid: LocalIdentifier) -> UIImage? {
        let uuid = luid.value
        guard let url = try? getBgDirectory().appendingPathComponent(uuid + ext) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    func deleteBgIfExists(for luid: LocalIdentifier) {
        let uuid = luid.value
        guard let url = try? getBgDirectory().appendingPathComponent(uuid + ext) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func persistBg(image: UIImage, for luid: LocalIdentifier) -> Future<URL, RUError> {
        let uuid = luid.value
        let promise = Promise<URL, RUError>()
        DispatchQueue.global().async {
            if let data = image.jpegData(compressionQuality: 1.0) {
                do {
                    let url = try self.getBgDirectory().appendingPathComponent(uuid + self.ext)
                    try data.write(to: url)
                    promise.succeed(value: url)
                } catch {
                    promise.fail(error: .persistence(error))
                }
            } else {
                promise.fail(error: .core(.failedToGetPngRepresentation))
            }
        }
        return promise.future
    }

    private func getBgDirectory() throws -> URL {
        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CoreError.failedToGetDocumentsDirectory
        }
        let dir = docDir.appendingPathComponent(bgDir, isDirectory: true)
        if !isBgDirCreated {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            isBgDirCreated = true
        }
        return dir
    }

}
