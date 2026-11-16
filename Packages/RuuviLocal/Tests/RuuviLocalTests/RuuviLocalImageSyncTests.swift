#if canImport(RuuviLocalUserDefaults)
@testable import RuuviLocalUserDefaults
#endif
@testable import RuuviLocal
import Future
import RuuviOntology
import UIKit
import XCTest

final class RuuviLocalImageSyncTests: XCTestCase {
    private let sensorId = "AA:BB:CC:DD:EE:97"
    private let persistence = ImagePersistenceSpy()
    private lazy var images = RuuviLocalImagesUserDefaults(imagePersistence: persistence)

    override func tearDown() {
        images.deleteCustomBackground(for: sensorId.mac)
        images.setPictureRemovedFromCache(for: sensor.ruuviTagSensor)
        UserDefaults.standard.removeObject(forKey: BackgroundImageRecord.prefix + sensorId)
        let luidKey = BackgroundImageRecord.prefix + "B7D8E6F1-45A4-4431-95F3-6CC96FEFC317"
        UserDefaults.standard.removeObject(forKey: luidKey)
        super.tearDown()
    }

    func testUserSelectionTimeSurvivesRelaunch() {
        let date = Date(timeIntervalSince1970: 100)
        images.setCustomBackgroundLastUpdated(date, for: sensorId.mac)
        let relaunched = RuuviLocalImagesUserDefaults(imagePersistence: persistence)
        XCTAssertEqual(relaunched.customBackgroundLastUpdated(for: sensorId.mac), date)
    }

    func testDownloadedImageIsNotTreatedAsANewUserSelection() {
        persistence.image = UIImage()
        images.setCustomBackgroundLastUpdated(Date(), for: sensorId.mac)
        images.setPictureIsCached(for: sensor)
        XCTAssertNil(images.customBackgroundLastUpdated(for: sensorId.mac))
        XCTAssertTrue(images.isPictureCached(for: sensor))
    }

    func testUserSelectionInvalidatesMatchingCloudCache() {
        persistence.image = UIImage()
        images.setPictureIsCached(for: sensor)
        images.setPictureRemovedFromCache(for: sensor.ruuviTagSensor)
        images.setCustomBackgroundLastUpdated(Date(), for: sensorId.mac)
        XCTAssertFalse(images.isPictureCached(for: sensor))
    }

    func testRemovingLocalImageClearsItsSelectionTimeAndCloudCache() {
        persistence.image = UIImage()
        images.setPictureIsCached(for: sensor)
        images.setCustomBackgroundLastUpdated(Date(), for: sensorId.mac)
        images.deleteCustomBackground(for: sensorId.mac)
        XCTAssertNil(images.customBackgroundLastUpdated(for: sensorId.mac))
        XCTAssertNil(images.getCustomBackground(for: sensorId.mac))
        XCTAssertFalse(images.isPictureCached(for: sensor))
    }

    func testDefaultBackgroundClearsSelectionAndInvalidatesCloudCache() {
        persistence.image = UIImage()
        images.setPictureIsCached(for: sensor)
        images.setCustomBackgroundLastUpdated(Date(), for: sensorId.mac)

        _ = images.setNextDefaultBackground(for: sensorId.mac)

        XCTAssertNil(images.customBackgroundLastUpdated(for: sensorId.mac))
        XCTAssertNil(images.userSelectedBackground(for: sensor.ruuviTagSensor))
        XCTAssertFalse(images.isPictureCached(for: sensor))
    }

    func testCachedFileWithoutUserSelectionTimeCannotBeUploaded() {
        persistence.image = UIImage()
        images.setPictureIsCached(for: sensor)
        XCTAssertNil(images.userSelectedBackground(for: sensor.ruuviTagSensor))
    }

    func testMissingSelectedImageCannotBeUploaded() {
        images.setCustomBackgroundLastUpdated(Date(), for: sensorId.mac)
        persistence.image = nil
        XCTAssertNil(images.userSelectedBackground(for: sensor.ruuviTagSensor))
    }

    func testSelectionKeepsItsOwnTimestamp() {
        persistence.image = UIImage()
        let selectedAt = Date(timeIntervalSince1970: 50)
        images.setCustomBackgroundLastUpdated(selectedAt, for: sensorId.mac)
        // The sensor metadata timestamp is 100; the image was selected at 50.
        XCTAssertEqual(images.userSelectedBackground(for: sensor.ruuviTagSensor)?.lastUpdated, selectedAt)
    }

    func testNewerBluetoothSelectionWinsOverOlderMacSelection() {
        let luid = "B7D8E6F1-45A4-4431-95F3-6CC96FEFC317".luid
        let macImage = UIImage()
        let selectedImage = UIImage()
        persistence.images[sensorId] = macImage
        persistence.images[luid.value] = selectedImage
        images.setCustomBackgroundLastUpdated(Date(timeIntervalSince1970: 20), for: sensorId.mac)
        images.setCustomBackgroundLastUpdated(Date(timeIntervalSince1970: 50), for: luid)
        defer { images.deleteCustomBackground(for: luid) }

        let background = images.userSelectedBackground(for: sensor.ruuviTagSensor.with(luid: luid))
        XCTAssertTrue(background?.image === selectedImage)
        XCTAssertEqual(background?.lastUpdated, Date(timeIntervalSince1970: 50))
    }

    func testSameCloudFilenameRemainsCachedWhenSignedURLChanges() {
        persistence.image = UIImage()
        images.setPictureIsCached(for: sensor)
        let refreshedURL = cloudSensor(picture: "https://example.com/image.jpg?signature=new")
        XCTAssertTrue(images.isPictureCached(for: refreshedURL))
    }

    func testRenamingDoesNotTurnDownloadedImageIntoUploadWhenCloudFilenameChanges() {
        persistence.image = UIImage()
        images.setPictureIsCached(for: sensor)
        let renamed = sensor.ruuviTagSensor.with(name: "Renamed").with(lastUpdated: Date(timeIntervalSince1970: 200))
        let changedCloud = cloudSensor(picture: "https://example.com/new-image.jpg")

        XCTAssertFalse(images.isPictureCached(for: changedCloud))
        XCTAssertNil(images.userSelectedBackground(for: renamed))
    }

    func testDownloadedMacImageCannotHidePendingBluetoothSelection() {
        let luid = "B7D8E6F1-45A4-4431-95F3-6CC96FEFC317".luid
        persistence.images[sensorId] = UIImage()
        persistence.images[luid.value] = UIImage()
        images.setCustomBackgroundLastUpdated(Date(timeIntervalSince1970: 50), for: luid)
        images.setPictureIsCached(for: sensor)
        defer { images.deleteCustomBackground(for: luid) }

        XCTAssertEqual(images.userSelectedBackground(for: sensor.ruuviTagSensor.with(luid: luid))?.lastUpdated,
                       Date(timeIntervalSince1970: 50))
    }

    func testBluetoothSelectionIsUsedWhenMacHasNoImage() {
        let luid = "B7D8E6F1-45A4-4431-95F3-6CC96FEFC317".luid
        let selectedImage = UIImage()
        persistence.images[luid.value] = selectedImage
        images.setCustomBackgroundLastUpdated(Date(timeIntervalSince1970: 50), for: luid)
        defer { images.deleteCustomBackground(for: luid) }

        let background = images.userSelectedBackground(for: sensor.ruuviTagSensor.with(luid: luid))
        XCTAssertTrue(background?.image === selectedImage)
        XCTAssertEqual(background?.lastUpdated, Date(timeIntervalSince1970: 50))
    }

    private var sensor: AnyCloudSensor { cloudSensor() }

    private func cloudSensor(picture: String = "https://example.com/image.jpg") -> AnyCloudSensor {
        CloudSensorStruct(
            id: sensorId, serviceUUID: nil, name: "Sensor", isClaimed: true, isOwner: true,
            owner: "owner@example.com", ownersPlan: "free", picture: URL(string: picture),
            offsetTemperature: nil, offsetHumidity: nil, offsetPressure: nil, isCloudSensor: true,
            canShare: true, sharedTo: [], sharedToPending: [], maxHistoryDays: 30,
            lastUpdated: Date(timeIntervalSince1970: 100)
        ).any
    }
}

extension RuuviLocalImageSyncTests {
    func testImageReadDoesNotWaitForUnrelatedJpegEncoding() {
        let first = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in UIColor.red.setFill() }
        let second = UIGraphicsImageRenderer(size: CGSize(width: 3, height: 3)).image { _ in UIColor.blue.setFill() }
        let encoderStarted = expectation(description: "Second encode started")
        let unblockEncoder = DispatchSemaphore(value: 0)
        let disk = ImagePersistenceDocuments(encode: { image, quality in
            XCTAssertFalse(Thread.isMainThread)
            if image === second {
                encoderStarted.fulfill()
                _ = unblockEncoder.wait(timeout: .now() + 3)
            }
            return image.jpegData(compressionQuality: quality)
        })
        let firstID = UUID().uuidString.luid
        let secondID = UUID().uuidString.luid
        defer {
            disk.deleteBgIfExists(for: firstID)
            disk.deleteBgIfExists(for: secondID)
        }
        let firstSaved = expectation(description: "First image saved")
        disk.persistBg(image: first, compressionQuality: 1, for: firstID)
            .on(success: { _ in firstSaved.fulfill() })
        wait(for: [firstSaved], timeout: 2)
        let secondSaved = expectation(description: "Second image saved")
        disk.persistBg(image: second, compressionQuality: 1, for: secondID)
            .on(success: { _ in secondSaved.fulfill() })
        wait(for: [encoderStarted], timeout: 2)
        let readFinished = expectation(description: "Read finished while encode is blocked")
        DispatchQueue.global(qos: .utility).async {
            XCTAssertTrue(disk.hasBg(for: firstID))
            XCTAssertNotNil(disk.fetchBg(for: firstID))
            XCTAssertNotNil(try? disk.fetchBgData(for: firstID))
            readFinished.fulfill()
        }
        wait(for: [readFinished], timeout: 1)
        unblockEncoder.signal()
        wait(for: [secondSaved], timeout: 2)
    }
}

final class ImagePersistenceSpy: ImagePersistence {
    var image: UIImage?
    var images: [String: UIImage] = [:]

    func hasBg(for identifier: Identifier) -> Bool { fetchBg(for: identifier) != nil }
    func fetchBgData(for identifier: Identifier) throws -> Data {
        guard let data = fetchBg(for: identifier)?.jpegData(compressionQuality: 1) else {
            throw RuuviLocalError.failedToGetJpegRepresentation
        }
        return data
    }
    func fetchBg(for identifier: Identifier) -> UIImage? { images[identifier.value] ?? image }
    func deleteBgIfExists(for identifier: Identifier) {
        image = nil
        images.removeValue(forKey: identifier.value)
    }
    func persistBg(image: UIImage, compressionQuality _: CGFloat, for _: Identifier)
    -> Future<URL, RuuviLocalError> {
        self.image = image
        let result = Promise<URL, RuuviLocalError>()
        result.succeed(value: FileManager.default.temporaryDirectory.appendingPathComponent("unused-image-test.jpg"))
        return result.future
    }
}
