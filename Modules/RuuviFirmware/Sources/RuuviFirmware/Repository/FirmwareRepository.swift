import Combine
import Foundation

public enum FirmwareRepositoryError: Error {
    case failedToGetDocumentsDirectory
    case fileNotFound
}

public protocol FirmwareRepository {
    func save(name: String, fileUrl: URL) throws -> URL
}

public final class FirmwareRepositoryImpl: FirmwareRepository {
    private let fwDir = "fw"
    private var isFwDirCreated = false

    public init() {}

    public func save(name: String, fileUrl: URL) throws -> URL {
        let dstUrl = try getFirmwareDirectory().appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: dstUrl.path) {
            try FileManager.default.removeItem(at: dstUrl)
        }
        try FileManager.default.copyItem(at: fileUrl, to: dstUrl)
        try FileManager.default.removeItem(at: fileUrl)
        return dstUrl
    }

    private func getFirmwareDirectory() throws -> URL {
        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
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
