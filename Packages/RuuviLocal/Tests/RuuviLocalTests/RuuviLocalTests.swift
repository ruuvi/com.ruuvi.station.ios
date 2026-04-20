@testable import RuuviLocal
import RuuviOntology
import UIKit
import XCTest

final class RuuviLocalTests: XCTestCase {
    func testPersistBgWritesFetchableImage() async throws {
        let persistence = ImagePersistenceDocuments()
        let identifier = UUID().uuidString.luid
        let image = makeImage(color: .systemRed)

        persistence.deleteBgIfExists(for: identifier)
        defer { persistence.deleteBgIfExists(for: identifier) }

        let url = try await persistence.persistBg(
            image: image,
            compressionQuality: 1,
            for: identifier
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(url.path.contains("/bg/"))

        let loadedImage = persistence.fetchBg(for: identifier)
        XCTAssertNotNil(loadedImage)
        XCTAssertEqual(loadedImage?.cgImage?.width, image.cgImage?.width)
        XCTAssertEqual(loadedImage?.cgImage?.height, image.cgImage?.height)
    }

    func testDeleteBgIfExistsRemovesPersistedImage() async throws {
        let persistence = ImagePersistenceDocuments()
        let identifier = UUID().uuidString.luid
        let image = makeImage(color: .systemBlue)

        persistence.deleteBgIfExists(for: identifier)

        let url = try await persistence.persistBg(
            image: image,
            compressionQuality: 1,
            for: identifier
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        persistence.deleteBgIfExists(for: identifier)

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNil(persistence.fetchBg(for: identifier))
    }

    func testPersistBgThrowsWhenImageHasNoJpegRepresentation() async {
        let persistence = ImagePersistenceDocuments()

        do {
            _ = try await persistence.persistBg(
                image: UIImage(),
                compressionQuality: 1,
                for: UUID().uuidString.luid
            )
            XCTFail("Expected persistBg to throw for an empty image")
        } catch RuuviLocalError.failedToGetJpegRepresentation {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPersistBgWrapsDiskWriteFailures() async {
        let expectedError = NSError(domain: "RuuviLocalTests", code: 42)
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RuuviLocalTests-\(UUID().uuidString)")
        let persistence = ImagePersistenceDocuments(
            documentsDirectory: { tempDirectory },
            dataWriter: { _, _ in throw expectedError }
        )
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        do {
            _ = try await persistence.persistBg(
                image: makeImage(color: .systemGreen),
                compressionQuality: 1,
                for: UUID().uuidString.luid
            )
            XCTFail("Expected disk write error")
        } catch let RuuviLocalError.disk(error as NSError) {
            XCTAssertEqual(error.domain, expectedError.domain)
            XCTAssertEqual(error.code, expectedError.code)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPersistBgThrowsWhenDocumentsDirectoryIsUnavailable() async {
        let persistence = ImagePersistenceDocuments(documentsDirectory: { nil })

        do {
            _ = try await persistence.persistBg(
                image: makeImage(color: .systemPurple),
                compressionQuality: 1,
                for: UUID().uuidString.luid
            )
            XCTFail("Expected missing documents directory error")
        } catch RuuviLocalError.failedToGetDocumentsDirectory {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeImage(color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }
}
