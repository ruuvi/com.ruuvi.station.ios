#if canImport(RuuviCloudPure)
import RuuviCloudPure
import RuuviCloudApi
#endif
import RuuviCloud
import RuuviLocal
import Future
import RuuviOntology
import RuuviPool
import RuuviUser
import XCTest

final class RuuviCloudImageSyncTests: XCTestCase {
    private let sensorId = "AA:BB:CC:DD:EE:FF"
    private let imageData = Data([1, 2, 3])
    private let selectedAt = Date(timeIntervalSince1970: 123.456)
    private let api = ImageAPIStub()
    private let pool = ImagePoolStub()
    private let user = ImageRetryUser()
    private lazy var cloud = RuuviCloudPure(api: api, user: user, pool: pool)

    func testLegacyResetIsRetiredWithoutAccessingTheCloud() throws {
        user.logout()
        let completed = expectation(description: "Reset retired")
        cloud.executeQueuedRequest(from: try request(action: .reset)).on(success: { retired in
            XCTAssertTrue(retired)
            completed.fulfill()
        }, failure: { error in XCTFail("Unexpected failure: \(error)") })
        wait(for: [completed], timeout: 2)
        XCTAssertEqual(api.uploads.count, 0)
        XCTAssertEqual(api.resetCalls, 0)
    }

    func testQueuedUploadReplaysTheSavedPayloadThroughCloudAPI() throws {
        let completed = expectation(description: "Upload retried")
        cloud.executeQueuedRequest(from: try request()).on(success: { uploaded in
            XCTAssertTrue(uploaded)
            completed.fulfill()
        }, failure: { error in XCTFail("Unexpected failure: \(error)") })
        XCTAssertEqual(api.uploads.count, 1)
        XCTAssertEqual(api.uploads.first?.data, imageData)
        XCTAssertEqual(api.uploads.first?.request.sensor, sensorId)
        XCTAssertEqual(api.uploads.first?.request.action, .upload)
        try succeedUpload()
        wait(for: [completed], timeout: 2)
        XCTAssertEqual(api.resetCalls, 0)
    }

    func testFailedUploadPersistsOriginalSelectionTimeBeforeCompleting() throws {
        var finished = false
        let completed = expectation(description: "Upload persisted for retry")
        cloud.upload(imageData: imageData, mimeType: .jpg, lastUpdated: selectedAt, progress: nil, for: sensorId.mac)
            .on(success: { _ in XCTFail("Failed upload must not report success") }, failure: { _ in
                finished = true
                completed.fulfill()
            })
        api.uploadResult.fail(error: .connection)
        XCTAssertFalse(finished)
        let queued = try XCTUnwrap(pool.queued.first)
        XCTAssertEqual(queued.type, .uploadImage)
        XCTAssertEqual(queued.requestDate, selectedAt)
        XCTAssertEqual(queued.additionalData, imageData)
        XCTAssertEqual(queued.uniqueKey, sensorId + "-uploadImage")
        let body = try XCTUnwrap(queued.requestBodyData)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(Set(payload.keys), ["sensor", "action", "type"])
        pool.persistence.succeed(value: true)
        wait(for: [completed], timeout: 2)
    }

    func testRetryFailureIsReportedSoTheQueueEntryCanBeRetained() throws {
        let completed = expectation(description: "Retry failed")
        cloud.executeQueuedRequest(from: try request()).on(success: { _ in
            XCTFail("Failed retry must remain pending")
        }, failure: { _ in completed.fulfill() })
        api.uploadResult.fail(error: .connection)
        wait(for: [completed], timeout: 2)
        XCTAssertEqual(api.uploads.count, 1)
        XCTAssertTrue(pool.queued.isEmpty)
    }

    func testMissingQueuedImageDataDoesNotCallTheAPI() throws {
        var queued = try request()
        queued.additionalData = nil
        let completed = expectation(description: "Invalid upload rejected")
        cloud.executeQueuedRequest(from: queued).on(success: { _ in XCTFail("Expected missing-data failure") },
                                                   failure: { _ in completed.fulfill() })
        wait(for: [completed], timeout: 2)
        XCTAssertTrue(api.uploads.isEmpty)
    }

    func testAccountSwitchDoesNotQueueThePreviousUsersImage() {
        let completed = expectation(description: "Session changed")
        cloud.upload(imageData: imageData, mimeType: .jpg, lastUpdated: selectedAt, progress: nil, for: sensorId.mac)
            .on(failure: { error in
                guard case .notAuthorized = error else { return XCTFail("Expected changed session") }
                completed.fulfill()
            })
        user.login(apiKey: "different-session")
        api.uploadResult.fail(error: .connection)
        wait(for: [completed], timeout: 2)
        XCTAssertTrue(pool.queued.isEmpty)
    }

    func testQueuePersistenceFailureStillCompletesTheUploadFailure() {
        let completed = expectation(description: "Queue persistence failed")
        cloud.upload(imageData: imageData, mimeType: .jpg, lastUpdated: selectedAt, progress: nil, for: sensorId.mac)
            .on(failure: { _ in completed.fulfill() })
        api.uploadResult.fail(error: .connection)
        pool.persistence.fail(error: .ruuviPersistence(.failedToFindRuuviTag))
        wait(for: [completed], timeout: 2)
    }

    func testSuccessfulUploadDoesNotCreateARetry() throws {
        let completed = expectation(description: "Upload succeeded")
        cloud.upload(imageData: imageData, mimeType: .jpg, lastUpdated: selectedAt, progress: nil, for: sensorId.mac)
            .on(success: { _ in completed.fulfill() }, failure: { error in XCTFail("Unexpected failure: \(error)") })
        try succeedUpload()
        wait(for: [completed], timeout: 2)
        XCTAssertTrue(pool.queued.isEmpty)
    }

    func testDenseSensorsPreserveTheCloudTimestampUsedByImageRetries() throws {
        let completed = expectation(description: "Cloud timestamp loaded")
        cloud.loadSensorsDense(
            for: nil, measurements: false, sharedToOthers: false,
            sharedToMe: true, alerts: false, settings: false
        ).on(success: { sensors in
            XCTAssertEqual(sensors.count, 1)
            XCTAssertEqual(sensors.first?.sensor.id, self.sensorId)
            XCTAssertEqual(sensors.first?.sensor.lastUpdated, Date(timeIntervalSince1970: 100))
            completed.fulfill()
        }, failure: { error in XCTFail("Unexpected failure: \(error)") })
        let json = """
        {"sensors":[{
            "sensor":"AA:BB:CC:DD:EE:FF", "owner":"owner@example.com", "name":"Test sensor",
            "picture":"https://image-sync.invalid/picture.jpg", "public":false,
            "canShare":true, "lastUpdated":100
        }]}
        """
        api.sensorsResult.succeed(value: try JSONDecoder().decode(
            RuuviCloudApiGetSensorsDenseResponse.self, from: Data(json.utf8)
        ))
        wait(for: [completed], timeout: 2)
    }

    func testSimultaneousUploadsOfSameSelectionShareOneRequest() throws {
        let first = expectation(description: "First caller")
        let second = expectation(description: "Sync caller")
        cloud.upload(imageData: imageData, mimeType: .jpg, lastUpdated: selectedAt, progress: nil, for: sensorId.mac)
            .on(success: { _ in first.fulfill() })
        cloud.upload(imageData: imageData, mimeType: .jpg, lastUpdated: selectedAt, progress: nil, for: sensorId.mac)
            .on(success: { _ in second.fulfill() })
        XCTAssertEqual(api.uploads.count, 1)
        try succeedUpload()
        wait(for: [first, second], timeout: 2)
    }

    func testNewSelectionWaitsForOlderUploadToFinish() throws {
        cloud.upload(imageData: imageData, mimeType: .jpg, lastUpdated: selectedAt,
                     progress: nil, for: sensorId.mac).on()
        let newer = expectation(description: "Newer selection uploaded")
        cloud.upload(imageData: Data([4]), mimeType: .jpg, lastUpdated: selectedAt.addingTimeInterval(1),
                     progress: nil, for: sensorId.mac).on(success: { _ in newer.fulfill() })
        XCTAssertEqual(api.uploads.count, 1)
        try succeedUpload()
        wait(for: [newer], timeout: 2)
        XCTAssertEqual(api.uploads.count, 2)
        XCTAssertEqual(api.uploads.last?.data, Data([4]))
    }

    private func request(action: RuuviCloudApiSensorImageUploadRequest.UploadAction = .upload)
    throws -> RuuviCloudQueuedRequestStruct {
        let body = RuuviCloudApiSensorImageUploadRequest(sensor: sensorId, action: action, mimeType: .jpg)
        return RuuviCloudQueuedRequestStruct(
            id: 1, type: .uploadImage, status: .failed, uniqueKey: sensorId + "-uploadImage",
            requestDate: selectedAt, successDate: nil, attempts: 1,
            requestBodyData: try JSONEncoder().encode(body), additionalData: imageData
        )
    }

    private func succeedUpload() throws {
        let response = try JSONDecoder().decode(
            RuuviCloudApiSensorImageUploadResponse.self,
            from: Data(#"{"uploadURL":"https://image-sync.invalid/picture.jpg"}"#.utf8)
        )
        api.uploadResult.succeed(value: response)
    }
}

extension RuuviCloudImageSyncTests {
    func testSupersededWaitingUploadIsSkipped() throws {
        cloud.upload(imageData: Data([1]), mimeType: .jpg, lastUpdated: selectedAt,
                     progress: nil, for: sensorId.mac).on()
        let skipped = expectation(description: "Intermediate selection skipped")
        cloud.upload(imageData: Data([2]), mimeType: .jpg, lastUpdated: selectedAt.addingTimeInterval(1),
                     progress: nil, for: sensorId.mac).on(failure: { _ in skipped.fulfill() })
        let latest = expectation(description: "Latest selection sent")
        cloud.upload(imageData: Data([3]), mimeType: .jpg, lastUpdated: selectedAt.addingTimeInterval(2),
                     progress: nil, for: sensorId.mac).on(success: { _ in latest.fulfill() })
        try succeedUpload()
        wait(for: [skipped, latest], timeout: 2)
        XCTAssertEqual(api.uploads.map { $0.data }, [Data([1]), Data([3])])
        XCTAssertTrue(pool.queued.isEmpty)
    }

    func testWaitingUploadRechecksLocalSelectionBeforeStarting() throws {
        cloud.upload(imageData: imageData, mimeType: .jpg, lastUpdated: selectedAt,
                     progress: nil, for: sensorId.mac).on()
        var isCurrent = true
        let skipped = expectation(description: "Cancelled selection skipped")
        cloud.upload(imageData: Data([2]), mimeType: .jpg, lastUpdated: selectedAt.addingTimeInterval(1),
                     progress: nil, isCurrentSelection: { isCurrent }, for: sensorId.mac)
            .on(failure: { _ in skipped.fulfill() })
        isCurrent = false
        try succeedUpload()
        wait(for: [skipped], timeout: 2)
        XCTAssertEqual(api.uploads.count, 1)
    }

    func testCanonicalProxyForwardsSelectionValidation() {
        let proxy = RuuviCloudCanonicalProxy(
            cloud: cloud, localIDs: RuuviLocalFactoryUserDefaults().createLocalIDs()
        )
        let skipped = expectation(description: "Proxy prevents superseded upload")
        proxy.upload(imageData: imageData, mimeType: .jpg, lastUpdated: selectedAt,
                     progress: nil, isCurrentSelection: { false }, for: sensorId.mac)
            .on(failure: { _ in skipped.fulfill() })
        wait(for: [skipped], timeout: 2)
        XCTAssertTrue(api.uploads.isEmpty)
    }

    func testSuccessfulNewSelectionRemovesOlderRetry() throws {
        pool.queued = [try request()]
        let uploaded = expectation(description: "New selection acknowledged")
        let newer = selectedAt.addingTimeInterval(1)
        cloud.upload(imageData: imageData, mimeType: .jpg, lastUpdated: newer,
                     progress: nil, for: sensorId.mac).on(success: { _ in uploaded.fulfill() })
        try succeedUpload()
        wait(for: [uploaded], timeout: 2)
        XCTAssertTrue(pool.queued.isEmpty)
        XCTAssertEqual(pool.acknowledgedImages.last?.1, newer)
    }

    func testCancelledInFlightFailureDoesNotRecreateRemovedRetry() {
        var isCurrent = true
        let failed = expectation(description: "Cancelled upload failed")
        cloud.upload(imageData: imageData, mimeType: .jpg, lastUpdated: selectedAt,
                     progress: nil, isCurrentSelection: { isCurrent }, for: sensorId.mac)
            .on(failure: { _ in failed.fulfill() })
        isCurrent = false
        api.uploadResult.fail(error: .connection)
        wait(for: [failed], timeout: 2)
        XCTAssertTrue(pool.queued.isEmpty)
    }
}

final class ImageRetryUser: RuuviUser {
    var apiKey: String? = "test-session"
    var email: String?
    var isAuthorized: Bool { apiKey != nil }
    func login(apiKey: String) { self.apiKey = apiKey }
    func logout() { apiKey = nil }
}
