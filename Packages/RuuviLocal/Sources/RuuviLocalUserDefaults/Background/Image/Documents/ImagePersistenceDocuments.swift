#if SWIFT_PACKAGE
    import RuuviLocal
#endif
import RuuviOntology
import UIKit

class ImagePersistenceDocuments: ImagePersistence {
    private let ext = ".png"
    private let bgDir = "bg"

    func fetchBg(for identifier: Identifier) -> UIImage? {
        let uuid = identifier.value
        guard let url = try? getBgDirectory().appendingPathComponent(uuid + ext) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    func deleteBgIfExists(for identifier: Identifier) {
        let uuid = identifier.value
        guard let url = try? getBgDirectory().appendingPathComponent(uuid + ext) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    @concurrent
    func persistBg(
        image: UIImage,
        compressionQuality: CGFloat,
        for identifier: Identifier
    ) async throws(RuuviLocalError) -> URL {
        guard !Task.isCancelled else { throw .disk(CancellationError()) }
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw .failedToGetJpegRepresentation
        }
        do {
            let url = try getBgDirectory().appendingPathComponent(identifier.value + ext)
            try Task.checkCancellation()
            try data.write(to: url, options: .atomic)
            return url
        } catch { throw .disk(error) }
    }

    private func getBgDirectory() throws -> URL {
        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            throw RuuviLocalError.failedToGetDocumentsDirectory
        }
        let dir = docDir.appendingPathComponent(bgDir, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
