@testable import RuuviService
@testable import RuuviLocal
import RuuviCloud
import RuuviCore
import RuuviOntology
import Future
import UIKit
import XCTest

final class SensorImageSyncTests: XCTestCase {
    private let mac = "AA:BB:CC:12:34:89".mac
    private let luid = "E6F7BA33-5B30-4079-9020-4800809361A5".luid
    private let disk = SyncImageDisk()
    private let api = ImageAPIStub()
    private let pool = ImagePoolStub()
    private lazy var images = RuuviLocalImagesUserDefaults(imagePersistence: disk)
    private lazy var cloud = RuuviCloudPure(api: api, user: ImageRetryUser(), pool: pool)
    private let download = Promise<UIImage, RuuviServiceError>()
    private var downloads = 0
    private lazy var sync = SensorImageSync(images: images, cloud: cloud, loadImage: { _ in
        self.downloads += 1
        return self.download.future
    })
    private var image: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }
    private var local: RuuviTagSensor { remote().ruuviTagSensor.with(luid: luid) }

    override func tearDown() {
        for id in [mac as Identifier, luid as Identifier, "00:00:00:12:34:89".mac as Identifier] {
            images.deleteCustomBackground(for: id)
            UserDefaults.standard.removeObject(forKey: BackgroundImageRecord.prefix + id.value)
            UserDefaults.standard.removeObject(forKey: "BackgroundPersistenceUserDefaults.background." + id.value)
        }
        super.tearDown()
    }

    func testClaimUploadsUndatedPhotoAndAcknowledgesIt() throws {
        disk.images[luid.value] = image
        let finished = expectation(description: "Claim image uploaded")
        sync.claim(local: local).on(success: { _ in finished.fulfill() }, failure: { XCTFail("\($0)") })
        awaitUploadCount(1)
        XCTAssertTrue(images.isBackgroundUploadForced(for: luid))
        try succeedUpload()
        wait(for: [finished], timeout: 2)
        XCTAssertNil(images.customBackgroundLastUpdated(for: luid))
        XCTAssertFalse(images.isBackgroundUploadForced(for: luid))
        XCTAssertNotNil(images.cachedPictureURL(for: luid))
    }

    func testFailedClaimRetainsPhotoAndForcedRetryAcrossRelaunch() {
        disk.images[mac.value] = image
        let finished = expectation(description: "Failed claim queued")
        sync.claim(local: local).on(failure: { _ in finished.fulfill() })
        api.uploadResult.fail(error: .connection)
        pool.persistence.succeed(value: true)
        wait(for: [finished], timeout: 2)
        let relaunched = RuuviLocalImagesUserDefaults(imagePersistence: disk)
        let nextSync = SensorImageSync(images: relaunched, cloud: cloud)
        XCTAssertEqual(nextSync.action(local: local, remote: remote(time: 9999999999)), .upload)
        XCTAssertNotNil(images.getCustomBackground(for: mac))
        XCTAssertEqual(nextSync.retryAction(selectedAt: pool.queued.first?.requestDate,
                                           local: local, remote: remote(time: 9999999999)), .upload)
    }

    func testClaimWithNoLocalPhotoDoesNotResetCloud() {
        sync.claim(local: local).on()
        XCTAssertTrue(api.uploads.isEmpty)
        XCTAssertEqual(api.resetCalls, 0)
    }

    func testRenameAndCalibrationDoNotAbandonRetryForUnchangedCloudImage() {
        selectPhoto(baseline: "old.jpg")
        let cloudAfterMetadataUpdate = remote(time: 500)
        XCTAssertEqual(sync.retryAction(selectedAt: Date(timeIntervalSince1970: 200),
                                        local: local, remote: cloudAfterMetadataUpdate), .upload)
        sync.sync(local: local, remote: cloudAfterMetadataUpdate).on()
        awaitUploadCount(1)
        XCTAssertEqual(downloads, 0)
    }

    func testChangedCloudImageWithUncertainAgePreservesPendingPhotoAndRetry() {
        selectPhoto(baseline: "previous.jpg")
        let before = disk.images[mac.value]
        XCTAssertEqual(sync.retryAction(selectedAt: Date(timeIntervalSince1970: 200),
                                        local: local, remote: remote(time: 500)), .preserve)
        sync.sync(local: local, remote: remote(time: 500)).on()
        XCTAssertTrue(disk.images[mac.value] === before)
        XCTAssertEqual(downloads, 0)
        XCTAssertTrue(api.uploads.isEmpty)
    }

    func testMissingCloudTimestampPreservesPendingPhotoAndRetry() {
        selectPhoto()
        XCTAssertEqual(sync.retryAction(selectedAt: Date(timeIntervalSince1970: 200),
                                        local: local, remote: remote(time: nil)), .preserve)
        sync.sync(local: local, remote: remote(time: nil)).on()
        XCTAssertNotNil(images.getCustomBackground(for: mac))
        XCTAssertTrue(api.uploads.isEmpty)
    }

    func testNewerLocalPhotoUploadsEvenWhenCloudFilenameChanged() {
        selectPhoto(baseline: "previous.jpg")
        sync.sync(local: local, remote: remote(time: 100)).on()
        awaitUploadCount(1)
        XCTAssertEqual(downloads, 0)
    }

    func testNoCloudPictureDoesNotErasePendingOrLegacyPhotos() {
        disk.images[luid.value] = image
        sync.sync(local: local, remote: remote(picture: nil)).on()
        XCTAssertNotNil(disk.images[luid.value])
        XCTAssertTrue(api.uploads.isEmpty)
        XCTAssertEqual(sync.retryAction(selectedAt: Date(timeIntervalSince1970: 50),
                                        local: local, remote: remote()), .preserve)
    }

    func testMissingPhotoDownloadsCloudEvenWhenLocalNameIsNewer() {
        let finished = expectation(description: "Downloaded")
        sync.sync(local: local.with(lastUpdated: Date(timeIntervalSince1970: 900)), remote: remote())
            .on(success: { _ in finished.fulfill() }, failure: { XCTFail("\($0)") })
        XCTAssertEqual(downloads, 1)
        download.succeed(value: image)
        wait(for: [finished], timeout: 2)
        XCTAssertNotNil(images.getCustomBackground(for: mac))
        XCTAssertTrue(images.isPictureCached(for: remote()))
        XCTAssertNil(images.customBackgroundLastUpdated(for: mac))
    }

    func testOriginalMacAndBluetoothSelectionBothBlockCanonicalDownload() {
        let canonical = remote(id: "00:00:00:12:34:89", time: 500)
        selectPhoto()
        XCTAssertEqual(sync.action(local: local, remote: canonical), .preserve)
        images.deleteCustomBackground(for: mac)
        disk.images[luid.value] = image
        images.setCustomBackgroundLastUpdated(Date(timeIntervalSince1970: 200), for: luid)
        XCTAssertEqual(sync.action(local: local, remote: canonical), .preserve)
    }

    func testSelectionDuringDownloadIsNotOverwritten() {
        let finished = expectation(description: "Download cancelled")
        sync.download(local: local, remote: remote()).on(success: { _ in XCTFail("Must retain selection") },
                                                       failure: { _ in finished.fulfill() })
        selectPhoto()
        let selected = disk.images[mac.value]
        download.succeed(value: image)
        wait(for: [finished], timeout: 2)
        XCTAssertTrue(disk.images[mac.value] === selected)
        XCTAssertEqual(images.customBackgroundLastUpdated(for: mac), Date(timeIntervalSince1970: 200))
    }

    func testSelectionStillBeingSavedCannotUploadPreviousFile() {
        selectPhoto()
        disk.heldWrite = Promise<URL, RuuviLocalError>()
        images.setCustomBackground(image: image, compressionQuality: 1, for: mac).on()
        sync.sync(local: local, remote: remote(time: 100)).on()
        XCTAssertTrue(api.uploads.isEmpty)
        XCTAssertEqual(downloads, 0)
        disk.heldWrite?.fail(error: .failedToGetJpegRepresentation)
    }

    func testOlderUploadCompletionCannotAcknowledgeNewSelection() throws {
        selectPhoto()
        sync.sync(local: local, remote: remote(time: 100)).on()
        let newer = Date(timeIntervalSince1970: 300)
        images.setCustomBackgroundLastUpdated(newer, for: mac)
        try succeedUpload()
        XCTAssertEqual(images.customBackgroundLastUpdated(for: mac), newer)
        XCTAssertNil(images.cachedPictureURL(for: mac))
    }

    func testOnlySupersededDatedRetryIsDiscarded() {
        selectPhoto()
        XCTAssertEqual(sync.retryAction(selectedAt: Date(timeIntervalSince1970: 100),
                                        local: local, remote: remote()), .discard)
        XCTAssertEqual(sync.retryAction(selectedAt: nil, local: local, remote: remote()), .preserve)
    }

    func testPicturelessCloudPreservesDefaultIndexAndSendsNoNotification() {
        images.setBackground(7, for: mac)
        var notifications = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .BackgroundPersistenceDidChangeBackground, object: nil, queue: nil
        ) { _ in notifications += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }
        sync.sync(local: local, remote: remote(picture: nil)).on()
        sync.sync(local: local, remote: remote(picture: nil)).on()
        let backgroundKey = "BackgroundPersistenceUserDefaults.background." + mac.value
        XCTAssertEqual(UserDefaults.standard.integer(forKey: backgroundKey), 7)
        XCTAssertEqual(notifications, 0)
    }

    func testRemovedCloudPictureClearsOnlyKnownCacheAndNotifies() {
        disk.images[mac.value] = image
        images.setCachedPictureURL(URL(string: "https://example.com/old.jpg"), for: mac)
        var notifications = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .BackgroundPersistenceDidChangeBackground, object: nil, queue: nil
        ) { _ in notifications += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }
        sync.sync(local: local, remote: remote(picture: nil)).on()
        XCTAssertNil(images.getCustomBackground(for: mac))
        XCTAssertNil(images.cachedPictureURL(for: mac))
        XCTAssertEqual(notifications, 1)
        XCTAssertEqual(api.resetCalls, 0)
    }

}

extension SensorImageSyncTests {
    func testPhotoSelectionPreservesCloudBaselineForFailedUploadRetry() {
        images.setCachedPictureURL(remote().picture, for: mac)
        let properties = RuuviServiceSensorPropertiesImpl(
            pool: pool, cloud: cloud, coreImage: SyncCoreImage(), localImages: images
        )
        let finished = expectation(description: "Selection failure queued")
        properties.set(image: image, for: local, progress: nil, maxSize: CGSize(width: 2, height: 2),
                       compressionQuality: 1).on(failure: { _ in finished.fulfill() })
        api.uploadResult.fail(error: .connection)
        pool.persistence.succeed(value: true)
        wait(for: [finished], timeout: 2)
        XCTAssertEqual(images.cachedPictureURL(for: mac), remote().picture)
        XCTAssertNotNil(images.customBackgroundLastUpdated(for: mac))
        XCTAssertEqual(sync.retryAction(selectedAt: pool.queued.first?.requestDate,
                                        local: local, remote: remote(time: 9999999999)), .upload)
    }

    func testFailedFileWriteRestoresPreviousClaimSelection() {
        selectPhoto()
        images.setBackgroundUploadForced(true, for: mac)
        disk.heldWrite = Promise<URL, RuuviLocalError>()
        let properties = RuuviServiceSensorPropertiesImpl(
            pool: pool, cloud: cloud, coreImage: SyncCoreImage(), localImages: images
        )
        let finished = expectation(description: "Failed file write restored selection")
        properties.set(image: image, for: local, progress: nil, maxSize: CGSize(width: 2, height: 2),
                       compressionQuality: 1).on(failure: { _ in finished.fulfill() })
        disk.heldWrite?.fail(error: .failedToGetJpegRepresentation)
        wait(for: [finished], timeout: 2)
        XCTAssertEqual(images.customBackgroundLastUpdated(for: mac), Date(timeIntervalSince1970: 200))
        XCTAssertTrue(images.isBackgroundUploadForced(for: mac))
        XCTAssertTrue(api.uploads.isEmpty)
    }

    func testRetryAllowsSQLiteMillisecondRounding() {
        selectPhoto()
        images.setCustomBackgroundLastUpdated(Date(timeIntervalSince1970: 200.1234), for: mac)
        XCTAssertEqual(sync.retryAction(selectedAt: Date(timeIntervalSince1970: 200.123),
                                        local: local, remote: remote()), .upload)
    }

    func testMissingSelectedFileFallsBackToCloudImage() {
        images.setCustomBackgroundLastUpdated(Date(timeIntervalSince1970: 200), for: mac)
        let finished = expectation(description: "Missing file restored from cloud")
        sync.sync(local: local, remote: remote()).on(success: { _ in finished.fulfill() })
        download.succeed(value: image)
        wait(for: [finished], timeout: 2)
        XCTAssertTrue(images.isPictureCached(for: remote()))
        XCTAssertNil(images.customBackgroundLastUpdated(for: mac))
        XCTAssertTrue(api.uploads.isEmpty)
    }

    private func awaitUploadCount(_ count: Int) {
        let condition = NSPredicate { _, _ in self.api.uploads.count == count }
        let ready = XCTNSPredicateExpectation(predicate: condition, object: nil)
        wait(for: [ready], timeout: 3)
    }

    private func selectPhoto(baseline: String? = nil) {
        disk.images[mac.value] = image
        images.setCustomBackgroundLastUpdated(Date(timeIntervalSince1970: 200), for: mac)
        images.setCachedPictureURL(baseline.flatMap { URL(string: "https://example.com/" + $0) }, for: mac)
    }

    private func remote(id: String? = nil, picture: String? = "old.jpg", time: TimeInterval? = 100) -> AnyCloudSensor {
        CloudSensorStruct(
            id: id ?? mac.value, serviceUUID: nil, name: "Sensor", isClaimed: true, isOwner: true,
            owner: "owner@example.com", ownersPlan: "free",
            picture: picture.flatMap { URL(string: "https://example.com/" + $0) },
            offsetTemperature: nil, offsetHumidity: nil, offsetPressure: nil, isCloudSensor: true,
            canShare: true, sharedTo: [], sharedToPending: [], maxHistoryDays: 30,
            lastUpdated: time.map { Date(timeIntervalSince1970: $0) }
        ).any
    }

    private func succeedUpload() throws {
        api.uploadResult.succeed(value: try JSONDecoder().decode(
            RuuviCloudApiSensorImageUploadResponse.self,
            from: Data(#"{"uploadURL":"https://example.com/uploaded.jpg"}"#.utf8)
        ))
    }
}

extension SensorImageSyncTests {
    func testHiddenLegacyBluetoothFileDoesNotBlockDisplayedCloudImage() {
        disk.images[mac.value] = image
        images.setCachedPictureURL(remote().picture, for: mac)
        disk.images[luid.value] = image
        let completed = expectation(description: "Cloud change replaces displayed image")
        sync.sync(local: local, remote: remote(picture: "changed.jpg"))
            .on(success: { _ in completed.fulfill() })
        XCTAssertEqual(downloads, 1)
        download.succeed(value: image)
        wait(for: [completed], timeout: 2)
        XCTAssertTrue(images.matchesCachedPicture(remote(picture: "changed.jpg").picture, for: mac))
        XCTAssertNotNil(disk.images[luid.value])
    }

    func testInterruptedSaveNeverPublishesNewDateForPreviousPhoto() {
        selectPhoto(baseline: "old.jpg")
        let original = images.getCustomBackground(for: mac)
        let replacement = image
        disk.heldWrite = Promise<URL, RuuviLocalError>()
        let committed = expectation(description: "Replacement committed")
        images.setUserSelectedBackground(image: replacement, compressionQuality: 1,
                                         selectedAt: Date(timeIntervalSince1970: 300), for: mac)
            .on(success: { _ in committed.fulfill() })
        // The new file has been staged, but a crash here still leaves the old published pair.
        let restartedBeforeCommit = RuuviLocalImagesUserDefaults(imagePersistence: disk)
        XCTAssertTrue(restartedBeforeCommit.getCustomBackground(for: mac) === original)
        XCTAssertEqual(restartedBeforeCommit.customBackgroundLastUpdated(for: mac), Date(timeIntervalSince1970: 200))
        disk.heldWrite?.succeed(value: URL(fileURLWithPath: "/tmp/staged.jpg"))
        wait(for: [committed], timeout: 2)
        let restartedAfterCommit = RuuviLocalImagesUserDefaults(imagePersistence: disk)
        XCTAssertTrue(restartedAfterCommit.getCustomBackground(for: mac) === replacement)
        XCTAssertEqual(restartedAfterCommit.customBackgroundLastUpdated(for: mac), Date(timeIntervalSince1970: 300))
    }

    func testCachedSyncDoesNotDecodeImageFiles() {
        disk.images[mac.value] = image
        disk.images[luid.value] = image
        images.setCachedPictureURL(remote().picture, for: mac)
        XCTAssertEqual(sync.action(local: local, remote: remote()), .none)
        XCTAssertEqual(disk.imageDecodes, 0)
    }

    func testUploadReadsSavedBytesOffMainThread() {
        selectPhoto()
        sync.sync(local: local, remote: remote()).on()
        awaitUploadCount(1)
        XCTAssertEqual(disk.dataReadOnMain, false)
    }

    func testAcknowledgedSelectionRetiresRetryEvenIfEarlierQueueCleanupFailed() throws {
        selectPhoto()
        let uploaded = expectation(description: "Upload acknowledged")
        sync.sync(local: local, remote: remote()).on(success: { _ in uploaded.fulfill() })
        awaitUploadCount(1)
        try succeedUpload()
        wait(for: [uploaded], timeout: 2)
        XCTAssertEqual(sync.retryAction(selectedAt: Date(timeIntervalSince1970: 200),
                                        local: local, remote: remote()), .discard)
    }

    func testUncommittedReplacementDoesNotLosePreviousPhotoRetry() {
        selectPhoto()
        let failed = expectation(description: "Original upload queued")
        sync.sync(local: local, remote: remote()).on(failure: { _ in failed.fulfill() })
        awaitUploadCount(1)
        disk.heldWrite = Promise<URL, RuuviLocalError>()
        images.setUserSelectedBackground(image: image, compressionQuality: 1,
                                         selectedAt: Date(timeIntervalSince1970: 300), for: mac).on()
        api.uploadResult.fail(error: .connection)
        pool.persistence.succeed(value: true)
        wait(for: [failed], timeout: 2)
        disk.heldWrite?.fail(error: .failedToGetJpegRepresentation)
        XCTAssertEqual(pool.queued.count, 1)
        XCTAssertEqual(pool.queued.first?.requestDate, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(images.customBackgroundLastUpdated(for: mac), Date(timeIntervalSince1970: 200))
    }

    func testRemovingPhotoRetiresItsDatedRetry() {
        selectPhoto()
        images.deleteCustomBackground(for: mac)
        XCTAssertEqual(sync.retryAction(selectedAt: Date(timeIntervalSince1970: 200),
                                        local: local, remote: remote()), .discard)
    }
}
