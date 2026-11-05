import Foundation
import RuuviLocal
#if SWIFT_PACKAGE
    @testable import RuuviLocalUserDefaults
#else
    @testable import RuuviLocal
#endif
import RuuviOntology
import UIKit
import XCTest

@MainActor final class LocalImagePersistenceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private let backgroundsKey = "BackgroundPersistenceUserDefaults.background.usedBackgroundsUDKey"
    override func setUp() {
        super.setUp()
        suite = "ruuvi-image-tests-" + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testDeviceDefaultsAndCyclingRespectCustomImagesAndAvoidPreviouslyUsedBackgrounds() throws {
        let persistence = ImageStoreSpy()
        let placeholder = makeImage()
        var names: [String] = []
        let images = RuuviLocalImagesUserDefaults(
            imagePersistence: persistence, defaults: defaults,
            notifications: NotificationCenter(),
            imageNamed: {
                names.append($0); return placeholder
            })
        let first = UUID().uuidString.luid
        let second = "AA:BB:CC:DD:EE:02".mac
        XCTAssertNil(images.getBackground(for: first))
        XCTAssertTrue(images.getOrGenerateBackground(for: first, ruuviDeviceType: .ruuviTag) === placeholder)
        XCTAssertEqual(names.last, "bg16")
        XCTAssertTrue(images.getOrGenerateBackground(for: second, ruuviDeviceType: .ruuviAir) === placeholder)
        XCTAssertEqual(names.last, "bg17")
        XCTAssertTrue(images.getBackground(for: first) === placeholder)
        XCTAssertEqual(names.last, "bg16")
        XCTAssertTrue(images.getOrGenerateBackground(for: first, ruuviDeviceType: .ruuviAir) === placeholder)
        XCTAssertEqual(names.last, "bg16", "Existing selection must survive a changed device classification")
        _ = images.setNextDefaultBackground(for: first)
        XCTAssertEqual(names.last, "bg17")
        _ = images.setNextDefaultBackground(for: first)
        XCTAssertEqual(names.last, "bg1")
        persistence.custom[first.value] = placeholder
        images.setBackground(0, for: first)
        XCTAssertTrue(images.getCustomBackground(for: first) === placeholder)
        XCTAssertTrue(images.getOrGenerateBackground(for: first, ruuviDeviceType: .ruuviAir) === placeholder)
        var used = Array(repeating: 10, count: 17)
        used[6] = 0
        defaults.set(used, forKey: backgroundsKey)
        _ = images.setNextDefaultBackground(for: first)
        XCTAssertEqual(names.last, "bg7")
        XCTAssertNil(persistence.custom[first.value])
        images.deleteCustomBackground(for: second)
        XCTAssertEqual(persistence.deleted.last, second.value)
        XCTAssertEqual((defaults.array(forKey: backgroundsKey) as? [Int])?[6], 1)
    }

    func testMalformedUsageStorageIsRepairedWithoutChoosingAnInvalidBackground() {
        let images = RuuviLocalImagesUserDefaults(
            imagePersistence: ImageStoreSpy(), defaults: defaults,
            notifications: NotificationCenter(),
            imageNamed: { name in
                let index = Int(name.dropFirst(2)) ?? 0
                XCTAssertTrue((1...17).contains(index))
                return nil
            })
        for value: Any in ["invalid", [1, 2], Array(repeating: -1, count: 17)] {
            defaults.set(value, forKey: backgroundsKey)
            let id = UUID().uuidString.luid
            _ = images.setNextDefaultBackground(for: id)
            let stored = defaults.array(forKey: backgroundsKey) as? [Int]
            XCTAssertEqual(stored?.count, 17)
            XCTAssertTrue(stored?.allSatisfy { $0 >= 0 } == true)
        }
    }

    func testUsageCountersCannotOverflow() {
        let images = RuuviLocalImagesUserDefaults(
            imagePersistence: ImageStoreSpy(), defaults: defaults,
            notifications: NotificationCenter())
        defaults.set(Array(repeating: Int.max, count: 17), forKey: backgroundsKey)
        images.setBackground(1, for: UUID().uuidString.luid)
        XCTAssertEqual((defaults.array(forKey: backgroundsKey) as? [Int])?.first, Int.max)
    }

    func testBackgroundAndUploadNotificationsObserveTheAlreadyPersistedValueForEachIdentifierType() {
        let notifications = NotificationCenter()
        let image = makeImage()
        let images = RuuviLocalImagesUserDefaults(
            imagePersistence: ImageStoreSpy(), defaults: defaults,
            notifications: notifications, imageNamed: { _ in image })
        for id: Identifier in [UUID().uuidString.luid, "AA:BB:CC:DD:EE:03".mac] {
            let backgroundKey: BPDidChangeBackgroundKey = id is MACIdentifier ? .macId : .luid
            let uploadKey: BPDidUpdateBackgroundUploadProgressKey = id is MACIdentifier ? .macId : .luid
            var changes = 0
            let changed = notifications.addObserver(
                forName: .BackgroundPersistenceDidChangeBackground,
                object: nil, queue: nil
            ) {
                changes += 1
                XCTAssertEqual(($0.userInfo?[backgroundKey] as? Identifier)?.value, id.value)
                XCTAssertTrue(images.getBackground(for: id) === image)
            }
            var uploads = 0
            let uploaded = notifications.addObserver(
                forName: .BackgroundPersistenceDidUpdateBackgroundUploadProgress,
                object: nil, queue: nil
            ) {
                uploads += 1
                XCTAssertEqual(($0.userInfo?[uploadKey] as? Identifier)?.value, id.value)
                XCTAssertEqual($0.userInfo?[BPDidUpdateBackgroundUploadProgressKey.progress] as? Double, 0.75)
                XCTAssertEqual(images.backgroundUploadProgress(for: id), 0.75)
            }
            XCTAssertNil(images.backgroundUploadProgress(for: id))
            images.setBackground(3, for: id)
            images.setBackgroundUploadProgress(percentage: 0.75, for: id)
            XCTAssertEqual(changes, 1)
            XCTAssertEqual(uploads, 1)
            images.deleteBackgroundUploadProgress(for: id)
            XCTAssertNil(images.backgroundUploadProgress(for: id))
            notifications.removeObserver(changed)
            notifications.removeObserver(uploaded)
        }
    }

    func testCustomBackgroundPublishesOnceAfterPersistenceAndFailuresKeepTheExistingSelection() async throws {
        let store = ImageStoreSpy()
        let notifications = NotificationCenter()
        let images = RuuviLocalImagesUserDefaults(
            imagePersistence: store, defaults: defaults,
            notifications: notifications, imageNamed: { _ in nil })
        let id = UUID().uuidString.luid
        let image = makeImage()
        var changes = 0
        let token = notifications.addObserver(
            forName: .BackgroundPersistenceDidChangeBackground,
            object: nil, queue: nil
        ) { _ in
            changes += 1
            XCTAssertTrue(store.saved)
            XCTAssertTrue(images.getBackground(for: id) === image)
        }
        defer { notifications.removeObserver(token) }
        let url = try await images.setCustomBackground(image: image, compressionQuality: 0.4, for: id)
        XCTAssertEqual(url, store.url)
        XCTAssertEqual(store.quality, 0.4)
        XCTAssertEqual(changes, 1)
        store.failure = .failedToGetJpegRepresentation
        do {
            _ = try await images.setCustomBackground(image: makeImage(), compressionQuality: 0.5, for: id)
            XCTFail("Expected image persistence error")
        } catch {
            guard case .failedToGetJpegRepresentation = error else { return XCTFail("Unexpected \(error)") }
        }
        XCTAssertEqual(changes, 1)
        XCTAssertTrue(images.getBackground(for: id) === image)
    }

    func testCloudPictureCacheIgnoresRotatingSignedURLsAndClearsBothLocalIdentifiers() {
        let images = RuuviLocalImagesUserDefaults(
            imagePersistence: ImageStoreSpy(), defaults: defaults,
            notifications: NotificationCenter())
        let first = sensor(picture: "https://example.com/photos/background.jpg?token=one")
        XCTAssertFalse(images.isPictureCached(for: first))
        images.setPictureIsCached(for: first)
        XCTAssertTrue(
            images.isPictureCached(for: sensor(picture: "https://example.com/photos/background.jpg?token=two")))
        XCTAssertFalse(images.isPictureCached(for: sensor(picture: "https://example.com/photos/new.jpg")))
        XCTAssertFalse(images.isPictureCached(for: sensor(picture: nil)))
        let noExtension = sensor(picture: "https://example.com/image?id=one")
        images.setPictureIsCached(for: noExtension)
        XCTAssertTrue(images.isPictureCached(for: noExtension))
        XCTAssertFalse(images.isPictureCached(for: sensor(picture: "https://example.com/image?id=two")))
        let luid = UUID().uuidString.luid
        let tag = RuuviTagSensorStruct(
            version: 5, firmwareVersion: nil, luid: luid, macId: first.id.mac,
            serviceUUID: nil, isConnectable: true, name: "test", isClaimed: true,
            isOwner: true, owner: nil, ownersPlan: nil, isCloudSensor: true,
            canShare: false, sharedTo: [], maxHistoryDays: nil)
        images.setBackground(3, for: luid)
        images.setBackground(4, for: first.id.mac)
        images.setPictureRemovedFromCache(for: tag)
        XCTAssertNil(defaults.object(forKey: "BackgroundPersistenceUserDefaults.background." + luid.value))
        XCTAssertNil(defaults.object(forKey: "BackgroundPersistenceUserDefaults.background." + first.id))
        XCTAssertFalse(images.isPictureCached(for: noExtension))
        images.setPictureIsCached(for: sensor(picture: nil))
        XCTAssertFalse(images.isPictureCached(for: first))
    }

    func testRealImageFilesRoundTripReplaceDeleteAndReportFailuresWithoutDamagingExistingFiles() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ImagePersistenceDocuments(directory: directory)
        let id = UUID().uuidString.luid
        XCTAssertNil(persistence.fetchBg(for: id))
        persistence.deleteBgIfExists(for: id)
        let first = try await persistence.persistBg(image: makeImage(), compressionQuality: 0.8, for: id)
        XCTAssertEqual(first.deletingLastPathComponent().path, directory.path)
        XCTAssertEqual(persistence.fetchBg(for: id)?.size, CGSize(width: 16, height: 12))
        let original = try Data(contentsOf: first)
        do {
            _ = try await persistence.persistBg(image: UIImage(), compressionQuality: 0.8, for: id)
            XCTFail("An empty image cannot overwrite a valid background")
        } catch { guard case .failedToGetJpegRepresentation = error else { return XCTFail("Unexpected \(error)") } }
        XCTAssertEqual(try Data(contentsOf: first), original)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await persistence.persistBg(image: makeImage(), compressionQuality: 0.8, for: id)
        }
        do { _ = try await task.value; XCTFail("Cancelled persistence must fail") } catch {}
        XCTAssertEqual(try Data(contentsOf: first), original)
        persistence.deleteBgIfExists(for: id)
        XCTAssertNil(persistence.fetchBg(for: id))
        let blocked = directory.appendingPathComponent("not-a-directory")
        try Data([0]).write(to: blocked)
        let unavailable = ImagePersistenceDocuments(directory: blocked)
        XCTAssertNil(unavailable.fetchBg(for: id))
        unavailable.deleteBgIfExists(for: id)
        do {
            _ = try await unavailable.persistBg(image: makeImage(), compressionQuality: 1, for: id)
            XCTFail("Expected a filesystem error")
        } catch { guard case .disk = error else { return XCTFail("Unexpected \(error)") } }
    }

    private func makeImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 16, height: 12), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 12))
        }
    }
    private func sensor(picture: String?) -> CloudSensorStruct {
        .init(
            id: "AA:BB:CC:DD:EE:03", serviceUUID: nil, name: "test", isClaimed: true, isOwner: true,
            owner: nil, ownersPlan: nil, picture: picture.flatMap(URL.init(string:)), offsetTemperature: nil,
            offsetHumidity: nil, offsetPressure: nil, isCloudSensor: true, canShare: false,
            sharedTo: [], maxHistoryDays: nil)
    }
}

private final class ImageStoreSpy: ImagePersistence {
    var custom: [String: UIImage] = [:]
    var deleted: [String] = []
    let url = URL(fileURLWithPath: "/saved/background.png")
    var quality: CGFloat?
    var saved = false
    var failure: RuuviLocalError?
    func fetchBg(for identifier: Identifier) -> UIImage? { custom[identifier.value] }
    func deleteBgIfExists(for identifier: Identifier) {
        custom[identifier.value] = nil; deleted.append(identifier.value)
    }
    func persistBg(image: UIImage, compressionQuality: CGFloat, for identifier: Identifier)
        async throws(RuuviLocalError) -> URL
    {
        if let failure { throw failure }
        quality = compressionQuality
        custom[identifier.value] = image
        saved = true
        return url
    }
}
