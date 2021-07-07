import Foundation
import Combine

enum FirmwareRepositoryError: Error {
    case failedToGetDocumentsDirectory
    case fileNotFound
}

protocol FirmwareRepository {
    func read(name: String) -> Future<URL, Error>
    func save(name: String, fileUrl: URL) throws -> URL
}

final class FirmwareRepositoryImpl: FirmwareRepository {
    private let fwDir = "fw"
    private var isFwDirCreated = false

    func read(name: String) -> Future<URL, Error> {
        return Future { [weak self] promise in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    if let dstUrl = try self?.getFirmwareDirectory().appendingPathComponent(name),
                       FileManager.default.fileExists(atPath: dstUrl.path) {
                        promise(.success(dstUrl))
                    } else {
                        promise(.failure(FirmwareRepositoryError.fileNotFound))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
    }

    func save(name: String, fileUrl: URL) throws -> URL {
        let dstUrl = try self.getFirmwareDirectory().appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: dstUrl.path) {
            try FileManager.default.removeItem(at: dstUrl)
        }
        try FileManager.default.copyItem(at: fileUrl, to: dstUrl)
        try FileManager.default.removeItem(at: fileUrl)
        return dstUrl
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
