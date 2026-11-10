#if canImport(RuuviCloudPure)
import RuuviCloudApi
@testable import RuuviCloudPure
#endif
@testable import RuuviCloud
import Future
import RuuviPool
import XCTest

final class RuuviCloudAlertRetryTests: XCTestCase {
    func testStateOnlyDisableOmitsThresholdsAndOtherSettingsFromTheWirePayload() throws {
        let request = RuuviCloudApiPostAlertRequest(
            sensor: "AA:BB:CC:DD:EE:FF", enabled: false, type: .soundPeak,
            min: nil, max: nil, description: nil, counter: nil, delay: nil, timestamp: 123
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        )
        XCTAssertEqual(Set(object.keys), ["sensor", "type", "enabled", "timestamp"])
        XCTAssertEqual(object["enabled"] as? Bool, false)
        XCTAssertEqual(object["type"] as? String, "soundPeak")
        XCTAssertEqual(object["sensor"] as? String, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(object["timestamp"] as? Int, 123)
    }

    func testWaitsForRetryPersistenceBeforeFinishingBackgroundAction() {
        let persistence = Promise<Bool, RuuviPoolError>()
        var completions = 0
        let completed = expectation(description: "Retry persisted")
        RuuviCloudAlertRetry.persist(error: .connection, isCurrentSession: true) {
            persistence.future
        }.on(failure: { error in
            guard case .api(.connection) = error else { return XCTFail("Original error was lost") }
        }, completion: {
            completions += 1
            completed.fulfill()
        })
        XCTAssertEqual(completions, 0)
        persistence.succeed(value: true)
        wait(for: [completed], timeout: 2)
        XCTAssertEqual(completions, 1)
    }

    func testAccountSwitchDoesNotEnqueueThePreviousAccountsRequest() {
        let completed = expectation(description: "Old session rejected")
        RuuviCloudAlertRetry.persist(error: .connection, isCurrentSession: false) {
            XCTFail("Must not queue across accounts")
            return nil
        }.on(failure: { error in
            guard case .notAuthorized = error else { return XCTFail("Expected expired session") }
            completed.fulfill()
        })
        wait(for: [completed], timeout: 2)
    }

    func testUnavailableQueueStillCompletesWithTheCloudFailure() {
        let completed = expectation(description: "Missing queue handled")
        RuuviCloudAlertRetry.persist(error: .connection, isCurrentSession: true, enqueue: { nil })
            .on(failure: { _ in completed.fulfill() })
        wait(for: [completed], timeout: 2)
    }

    func testPersistenceFailureDoesNotStrandTheNotificationCallback() {
        let persistence = Promise<Bool, RuuviPoolError>()
        let completed = expectation(description: "Persistence failure handled")
        RuuviCloudAlertRetry.persist(error: .connection, isCurrentSession: true) {
            persistence.future
        }.on(failure: { _ in completed.fulfill() })
        persistence.fail(error: .ruuviPersistence(.failedToFindRuuviTag))
        wait(for: [completed], timeout: 2)
    }
}
