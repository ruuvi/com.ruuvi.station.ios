import Foundation

enum FirmwareRepositoryError: Error {
    case failedToGetDocumentsDirectory
}

protocol FirmwareRepository {
    func save(name: String, fileUrl: URL) throws
}

final class FirmwareRepositoryImpl: FirmwareRepository {
    private let fwDir = "fw"
    private var isFwDirCreated = false

    func save(name: String, fileUrl: URL) throws {
        let dstUrl = try self.getFirmwareDirectory().appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: dstUrl.path) {
            try FileManager.default.removeItem(at: dstUrl)
        }
        try FileManager.default.copyItem(at: fileUrl, to: dstUrl)
        try FileManager.default.removeItem(at: fileUrl)
    }

    private func getFirmwareDirectory() throws -> URL {
        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw FirmwareRepositoryError.failedToGetDocumentsDirectory
        }
        let dir = docDir.appendingPathComponent(fwDir, isDirectory: true)
        if !isFwDirCreated {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            isFwDirCreated = true
        }
        return dir
    }
}
