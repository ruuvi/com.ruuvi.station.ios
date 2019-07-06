import UIKit
import Future

class ImagePersistenceDocuments: ImagePersistence {
    
    private let ext = ".png"
    
    func fetch(uuid: String) -> UIImage? {
        let url = getDocumentsDirectory().appendingPathComponent(uuid + ext)
        return UIImage(contentsOfFile: url.path)
    }
    
    func delete(uuid: String) {
        let url = getDocumentsDirectory().appendingPathComponent(uuid + ext)
        try? FileManager.default.removeItem(at: url)
    }
    
    func persist(image: UIImage, for uuid: String) -> Future<URL,RUError> {
        let promise = Promise<URL,RUError>()
        if let data = image.pngData() {
            let url = getDocumentsDirectory().appendingPathComponent(uuid + ext)
            do {
                try data.write(to: url)
                promise.succeed(value: url)
            } catch {
                promise.fail(error: .persistence(error))
            }
        } else {
            promise.fail(error: .core(.failedToGetPngRepresentation))
        }
        return promise.future
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
}
