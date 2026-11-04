import Foundation

public enum FirmwareRepositoryError: Error {
    case failedToGetDocumentsDirectory
    case fileNotFound
    case invalidFileName
}

public protocol FirmwareRepository {
    func save(name: String, fileUrl: URL) throws -> URL
}

public final class FirmwareRepositoryImpl: FirmwareRepository {
    private let directory: URL?

    public init() { directory = nil }

    init(directory: URL) { self.directory = directory }

    public func save(name: String, fileUrl: URL) throws -> URL {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\\") else {
            throw FirmwareRepositoryError.invalidFileName
        }
        guard fileUrl.isFileURL, FileManager.default.fileExists(atPath: fileUrl.path) else {
            throw FirmwareRepositoryError.fileNotFound
        }
        let destination = try getFirmwareDirectory().appendingPathComponent(name)
        guard destination.standardizedFileURL != fileUrl.standardizedFileURL else { return destination }
        // Keep the previous valid download until its replacement has been written successfully.
        let data = try Data(contentsOf: fileUrl, options: .mappedIfSafe)
        try data.write(to: destination, options: .atomic)
        try FileManager.default.removeItem(at: fileUrl)
        return destination
    }

    private func getFirmwareDirectory() throws -> URL {
        let destination: URL
        if let directory {
            destination = directory
        } else {
            guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw FirmwareRepositoryError.failedToGetDocumentsDirectory
            }
            destination = documents.appendingPathComponent("fw", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        return destination
    }
}
