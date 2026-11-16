@testable import RuuviService
@testable import RuuviLocal
import RuuviCloud
import RuuviOntology
import Future
import UIKit
import XCTest

final class SensorImageDownloadTests: XCTestCase {
    private let mac = "AA:BB:CC:12:34:90".mac
    private let luid = "B55C5405-80ED-4561-A6BE-7B639B0E7725".luid
    private let disk = SyncImageDisk()
    private lazy var images = RuuviLocalImagesUserDefaults(imagePersistence: disk)
    private let olderResponse = Promise<UIImage, RuuviServiceError>()
    private let newerResponse = Promise<UIImage, RuuviServiceError>()
    private lazy var sync = SensorImageSync(
        images: images, cloud: RuuviCloudPure(api: ImageAPIStub(), user: ImageRetryUser(), pool: ImagePoolStub()),
        loadImage: { url in
            url.lastPathComponent == "older.jpg" ? self.olderResponse.future : self.newerResponse.future
        }
    )
    private var local: RuuviTagSensor { remote("older.jpg").ruuviTagSensor.with(luid: luid) }

    override func tearDown() {
        for identifier in [mac as Identifier, luid as Identifier] {
            images.deleteCustomBackground(for: identifier)
            UserDefaults.standard.removeObject(forKey: BackgroundImageRecord.prefix + identifier.value)
            let backgroundKey = "BackgroundPersistenceUserDefaults.background." + identifier.value
            UserDefaults.standard.removeObject(forKey: backgroundKey)
        }
        super.tearDown()
    }

    func testOlderNetworkResponseCannotReplaceNewerCloudImage() {
        let rejected = expectRejection(sync.download(local: local, remote: remote("older.jpg")))
        let saved = expectSuccess(sync.download(local: local, remote: remote("newer.jpg")))
        let newest = UIImage()
        newerResponse.succeed(value: newest)
        wait(for: [saved], timeout: 2)
        olderResponse.succeed(value: UIImage())
        wait(for: [rejected], timeout: 2)
        assertCached(newest, name: "newer.jpg")
    }

    func testOlderDiskWriteCannotReplaceNewerCloudImage() {
        let heldWrite = holdOlderWrite()
        let saved = expectSuccess(sync.download(local: local, remote: remote("newer.jpg")))
        let newest = UIImage()
        newerResponse.succeed(value: newest)
        wait(for: [saved], timeout: 2)
        heldWrite.promise.succeed(value: FileManager.default.temporaryDirectory.appendingPathComponent("older.jpg"))
        wait(for: [heldWrite.rejected], timeout: 2)
        assertCached(newest, name: "newer.jpg")
    }

    func testOlderDiskWriteIsRejectedWhileNewerDownloadIsStillRunning() {
        let heldWrite = holdOlderWrite()
        let saved = expectSuccess(sync.download(local: local, remote: remote("newer.jpg")))
        heldWrite.promise.succeed(value: FileManager.default.temporaryDirectory.appendingPathComponent("older.jpg"))
        wait(for: [heldWrite.rejected], timeout: 2)
        XCTAssertNil(images.getCustomBackground(for: mac))
        XCTAssertNil(images.cachedPictureURL(for: mac))
        let newest = UIImage()
        newerResponse.succeed(value: newest)
        wait(for: [saved], timeout: 2)
        assertCached(newest, name: "newer.jpg")
    }

    func testAlreadyCachedSnapshotInvalidatesOlderDownload() {
        let rejected = expectRejection(sync.download(local: local, remote: remote("older.jpg")))
        let newest = UIImage()
        disk.images[mac.value] = newest
        images.setCachedPictureURL(remote("newer.jpg").picture, for: mac)
        sync.sync(local: local, remote: remote("newer.jpg")).on()
        olderResponse.succeed(value: UIImage())
        wait(for: [rejected], timeout: 2)
        assertCached(newest, name: "newer.jpg")
    }

    func testRemovedCloudPictureInvalidatesPendingDiskWrite() {
        let heldWrite = holdOlderWrite()
        sync.sync(local: local, remote: remote(nil)).on()
        heldWrite.promise.succeed(value: FileManager.default.temporaryDirectory.appendingPathComponent("older.jpg"))
        wait(for: [heldWrite.rejected], timeout: 2)
        XCTAssertNil(images.getCustomBackground(for: mac))
        XCTAssertNil(images.cachedPictureURL(for: mac))
    }

    func testBluetoothSelectionDuringDiskWriteIsPreserved() {
        let heldWrite = holdOlderWrite()
        let selected = UIImage()
        disk.images[luid.value] = selected
        images.setCustomBackgroundLastUpdated(Date(), for: luid)
        heldWrite.promise.succeed(value: FileManager.default.temporaryDirectory.appendingPathComponent("older.jpg"))
        wait(for: [heldWrite.rejected], timeout: 2)
        XCTAssertTrue(images.customBackground(for: local)?.image === selected)
        XCTAssertNil(images.getCustomBackground(for: mac))
        XCTAssertNil(images.cachedPictureURL(for: mac))
    }

    private func holdOlderWrite()
    -> (promise: Promise<URL, RuuviLocalError>, rejected: XCTestExpectation) {
        let held = Promise<URL, RuuviLocalError>()
        disk.heldWrite = held
        let rejected = expectRejection(sync.download(local: local, remote: remote("older.jpg")))
        olderResponse.succeed(value: UIImage())
        let condition = NSPredicate { _, _ in !self.disk.images.isEmpty }
        let staged = XCTNSPredicateExpectation(predicate: condition, object: nil)
        wait(for: [staged], timeout: 2)
        disk.heldWrite = nil
        return (held, rejected)
    }

    private func expectRejection(_ future: Future<URL, RuuviServiceError>) -> XCTestExpectation {
        let rejected = expectation(description: "Superseded download rejected")
        future.on(success: { _ in XCTFail("A superseded image must never be published") },
                  failure: { _ in rejected.fulfill() })
        return rejected
    }

    private func expectSuccess(_ future: Future<URL, RuuviServiceError>) -> XCTestExpectation {
        let saved = expectation(description: "Current image saved")
        future.on(success: { _ in saved.fulfill() }, failure: { XCTFail("\($0)") })
        return saved
    }

    private func assertCached(_ image: UIImage, name: String) {
        XCTAssertTrue(images.getCustomBackground(for: mac) === image)
        XCTAssertEqual(images.cachedPictureURL(for: mac), remote(name).picture)
        XCTAssertNil(images.customBackgroundLastUpdated(for: mac))
    }

    private func remote(_ picture: String?) -> AnyCloudSensor {
        CloudSensorStruct(
            id: mac.value, serviceUUID: nil, name: "Sensor", isClaimed: true, isOwner: true,
            owner: "owner@example.com", ownersPlan: "free",
            picture: picture.flatMap { URL(string: "https://example.com/" + $0) },
            offsetTemperature: nil, offsetHumidity: nil, offsetPressure: nil, isCloudSensor: true,
            canShare: true, sharedTo: [], sharedToPending: [], maxHistoryDays: 30,
            lastUpdated: Date(timeIntervalSince1970: 100)
        ).any
    }
}
