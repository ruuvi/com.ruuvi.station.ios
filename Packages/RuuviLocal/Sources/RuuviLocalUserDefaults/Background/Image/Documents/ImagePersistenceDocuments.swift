import RuuviOntology
import UIKit

class ImagePersistenceDocuments: ImagePersistence {
    private let ext = ".png"
    private let bgDir = "bg"
    private let fileManager: FileManager
    private let documentsDirectory: () -> URL?
    private let dataWriter: (Data, URL) throws -> Void

    init(
        fileManager: FileManager = .default,
        documentsDirectory: @escaping () -> URL? = {
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        },
        dataWriter: @escaping (Data, URL) throws -> Void = { data, url in
            try data.write(to: url)
        }
    ) {
        self.fileManager = fileManager
        self.documentsDirectory = documentsDirectory
        self.dataWriter = dataWriter
    }

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
        let ext = self.ext
        let dataWriter = self.dataWriter
        let directory = try getBgDirectory()
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                if let data = image.jpegData(compressionQuality: compressionQuality) {
                    do {
                        let url = directory.appendingPathComponent(uuid + ext)
                        try dataWriter(data, url)
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
        guard let docDir = documentsDirectory()
        else {
            throw RuuviLocalError.failedToGetDocumentsDirectory
        }
        let dir = docDir.appendingPathComponent(bgDir, isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
