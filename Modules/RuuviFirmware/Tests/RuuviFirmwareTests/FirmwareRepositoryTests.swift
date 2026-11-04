import Foundation
import XCTest
@testable import RuuviFirmware

final class FirmwareRepositoryTests: XCTestCase {
    func testDownloadIsMovedAndExistingFirmwareIsReplaced() throws {
        try withDirectory { directory in
            let cache = directory.appendingPathComponent("cache")
            let repository = FirmwareRepositoryImpl(directory: cache)
            let download = directory.appendingPathComponent("download.zip")
            try Data("old firmware".utf8).write(to: download)
            let saved = try repository.save(name: "firmware.zip", fileUrl: download)
            XCTAssertEqual(saved, cache.appendingPathComponent("firmware.zip"))
            XCTAssertFalse(FileManager.default.fileExists(atPath: download.path))
            XCTAssertEqual(try Data(contentsOf: saved), Data("old firmware".utf8))
            try Data("new firmware".utf8).write(to: download)
            XCTAssertEqual(try repository.save(name: "firmware.zip", fileUrl: download), saved)
            XCTAssertEqual(try Data(contentsOf: saved), Data("new firmware".utf8))
        }
    }

    func testMissingOrUnreadableReplacementCannotDeleteExistingFirmware() throws {
        try withDirectory { directory in
            let repository = FirmwareRepositoryImpl(directory: directory)
            let existing = directory.appendingPathComponent("firmware.zip")
            let original = Data("valid cached firmware".utf8)
            try original.write(to: existing)
            XCTAssertThrowsError(
                try repository.save(name: "firmware.zip", fileUrl: directory.appendingPathComponent("missing")))
            XCTAssertEqual(try Data(contentsOf: existing), original)
            let folder = directory.appendingPathComponent("not-a-file")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            XCTAssertThrowsError(try repository.save(name: "firmware.zip", fileUrl: folder))
            XCTAssertEqual(try Data(contentsOf: existing), original)
        }
    }

    func testSavingAlreadyCachedFileDoesNotRemoveItAndDeletedCacheDirectoryIsRecreated() throws {
        try withDirectory { directory in
            let cache = directory.appendingPathComponent("cache")
            let repository = FirmwareRepositoryImpl(directory: cache)
            let source = directory.appendingPathComponent("source")
            try Data([1, 2, 3]).write(to: source)
            let saved = try repository.save(name: "firmware.zip", fileUrl: source)
            XCTAssertEqual(try repository.save(name: "firmware.zip", fileUrl: saved), saved)
            XCTAssertEqual(try Data(contentsOf: saved), Data([1, 2, 3]))
            try FileManager.default.removeItem(at: cache)
            try Data([4, 5, 6]).write(to: source)
            XCTAssertEqual(try repository.save(name: "firmware.zip", fileUrl: source), saved)
            XCTAssertEqual(try Data(contentsOf: saved), Data([4, 5, 6]))
        }
    }

    func testAssetNamesCannotEscapeFirmwareDirectoryAndFailedWriteKeepsDownload() throws {
        try withDirectory { directory in
            let source = directory.appendingPathComponent("source")
            try Data([1, 2, 3]).write(to: source)
            let repository = FirmwareRepositoryImpl(directory: directory.appendingPathComponent("cache"))
            for name in ["", ".", "..", "../firmware.zip", "/firmware.zip", "folder/file.zip", "folder\\file.zip"] {
                XCTAssertThrowsError(try repository.save(name: name, fileUrl: source)) { error in
                    guard case FirmwareRepositoryError.invalidFileName = error else {
                        return XCTFail("Unexpected \(error)")
                    }
                }
            }
            let blocked = FirmwareRepositoryImpl(directory: source)
            XCTAssertThrowsError(try blocked.save(name: "firmware.zip", fileUrl: source))
            XCTAssertEqual(try Data(contentsOf: source), Data([1, 2, 3]))
        }
    }

    private func withDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}
