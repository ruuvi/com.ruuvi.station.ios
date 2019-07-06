import UIKit
import Future

class ImagePersistenceDocuments: ImagePersistence {
    
    private let ext = ".png"
    private let bgDir = "bg"
    private var isBgDirCreated = false
    
    func fetch(uuid: String) -> UIImage? {
        guard let url = try? getBgDirectory().appendingPathComponent(uuid + ext) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    
    func delete(uuid: String) {
        guard let url = try? getBgDirectory().appendingPathComponent(uuid + ext) else { return }
        try? FileManager.default.removeItem(at: url)
    }
    
    func persist(image: UIImage, for uuid: String) -> Future<URL,RUError> {
        let promise = Promise<URL,RUError>()
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
