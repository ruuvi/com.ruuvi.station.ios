import Future
import RuuviOntology
import UIKit

class ImagePersistenceDocuments: ImagePersistence {
    private static let diskQueue = DispatchQueue(label: "ImagePersistenceDocuments.write", qos: .utility)
    private let writeQueue = ImagePersistenceDocuments.diskQueue
    private let encode: (UIImage, CGFloat) -> Data?

    init(encode: @escaping (UIImage, CGFloat) -> Data? = { $0.jpegData(compressionQuality: $1) }) {
        self.encode = encode
        _ = Self.recoverUnpublishedFiles
    }

    /// Run once, before this process can stage any new files on the shared disk queue.
    private static let recoverUnpublishedFiles: Void = {
        diskQueue.async(execute: removeUnpublishedFiles)
    }()

    private static func removeUnpublishedFiles() {
        let records = UserDefaults.standard.dictionaryRepresentation()
        let liveFiles = Set(records.compactMap { key, value -> String? in
            guard key.hasPrefix(BackgroundImageRecord.prefix) else { return nil }
            return (value as? [String: Any])?["file"] as? String
        })
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let files = try? FileManager.default.contentsOfDirectory(
                at: documents.appendingPathComponent("bg"), includingPropertiesForKeys: nil
              ) else { return }
        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
            guard name.hasPrefix("image-"), UUID(uuidString: String(name.dropFirst(6))) != nil,
                  !liveFiles.contains(name) else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }
    private let ext = ".png"
    private let bgDir = "bg"
    private var isBgDirCreated = false

    func hasBg(for identifier: Identifier) -> Bool {
        guard let url = try? backgroundURL(for: identifier) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func fetchBgData(for identifier: Identifier) throws -> Data {
        try Data(contentsOf: backgroundURL(for: identifier))
    }

    func fetchBg(for identifier: Identifier) -> UIImage? {
        guard let url = try? backgroundURL(for: identifier) else { return nil }
        // Published files are immutable. Reads never wait behind an image encode.
        return UIImage(contentsOfFile: url.path)
    }

    func deleteBgIfExists(for identifier: Identifier) {
        writeQueue.async {
            guard let url = try? self.backgroundURL(for: identifier) else { return }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func backgroundURL(for identifier: Identifier) throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw RuuviLocalError.failedToGetDocumentsDirectory
        }
        return documents.appendingPathComponent(bgDir).appendingPathComponent(identifier.value + ext)
    }

    func persistBg(
        image: UIImage,
        compressionQuality: CGFloat,
        for identifier: Identifier
    ) -> Future<URL, RuuviLocalError> {
        let uuid = identifier.value
        let promise = Promise<URL, RuuviLocalError>()
        writeQueue.async {
            if let data = self.encode(image, compressionQuality) {
                do {
                    let url = try self.getBgDirectory().appendingPathComponent(uuid + self.ext)
                    try data.write(to: url, options: .atomic)
                    promise.succeed(value: url)
                } catch {
                    promise.fail(error: .disk(error))
                }
            } else {
                promise.fail(error: .failedToGetJpegRepresentation)
            }
        }
        return promise.future
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
