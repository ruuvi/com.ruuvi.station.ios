import RuuviOntology
import UIKit

class ImagePersistenceDocuments: ImagePersistence {
    private let ext = ".png"
    private let bgDir = "bg"
    private var isBgDirCreated = false

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

    func persistBg(
        image: UIImage,
        compressionQuality: CGFloat,
        for identifier: Identifier
    ) async throws -> URL {
        let uuid = identifier.value
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                if let data = image.jpegData(compressionQuality: compressionQuality) {
                    do {
                        let url = try self.getBgDirectory().appendingPathComponent(uuid + self.ext)
                        try data.write(to: url)
                        continuation.resume(returning: url)
                    } catch {
                        continuation.resume(throwing: RuuviLocalError.disk(error))
                    }
                } else {
                    continuation.resume(throwing: RuuviLocalError.failedToGetJpegRepresentation)
                }
            }
        }
    }

    private func getBgDirectory() throws -> URL {
        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            throw RuuviLocalError.failedToGetDocumentsDirectory
        }
        let dir = docDir.appendingPathComponent(bgDir, isDirectory: true)
        if !isBgDirCreated {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            isBgDirCreated = true
        }
        return dir
    }
}
