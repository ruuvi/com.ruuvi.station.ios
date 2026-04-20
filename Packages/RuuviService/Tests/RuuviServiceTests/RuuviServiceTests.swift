@testable import RuuviService
import RuuviCloud
import RuuviLocal
import RuuviPersistence
import RuuviPool
import RuuviRepository
import RuuviStorage
import XCTest

final class RuuviServiceTests: XCTestCase {
    func testPerformReturnsValue() async throws {
        let value = try await RuuviServiceError.perform { 42 }

        XCTAssertEqual(value, 42)
    }

    func testPerformPassesThroughServiceError() async {
        do {
            _ = try await RuuviServiceError.perform {
                throw RuuviServiceError.macIdIsNil
            }
            XCTFail("Expected perform to throw")
        } catch let error as RuuviServiceError {
            guard case .macIdIsNil = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testPerformMapsCloudError() async {
        do {
            _ = try await RuuviServiceError.perform {
                throw RuuviCloudError.notAuthorized
            }
            XCTFail("Expected perform to throw")
        } catch let error as RuuviServiceError {
            guard case let .ruuviCloud(cloudError) = error,
                  case .notAuthorized = cloudError else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testPerformMapsPoolError() async {
        do {
            _ = try await RuuviServiceError.perform {
                throw RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)
            }
            XCTFail("Expected perform to throw")
        } catch let error as RuuviServiceError {
            guard case let .ruuviPool(poolError) = error,
                  case let .ruuviPersistence(persistenceError) = poolError,
                  case .failedToFindRuuviTag = persistenceError else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testPerformMapsRepositoryError() async {
        do {
            _ = try await RuuviServiceError.perform {
                throw RuuviRepositoryError.ruuviStorage(.ruuviPersistence(.failedToFindRuuviTag))
            }
            XCTFail("Expected perform to throw")
        } catch let error as RuuviServiceError {
            guard case let .ruuviRepository(repositoryError) = error,
                  case let .ruuviStorage(storageError) = repositoryError,
                  case let .ruuviPersistence(persistenceError) = storageError,
                  case .failedToFindRuuviTag = persistenceError else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testPerformMapsStorageError() async {
        do {
            _ = try await RuuviServiceError.perform {
                throw RuuviStorageError.ruuviPersistence(.failedToFindRuuviTag)
            }
            XCTFail("Expected perform to throw")
        } catch let error as RuuviServiceError {
            guard case let .ruuviStorage(storageError) = error,
                  case let .ruuviPersistence(persistenceError) = storageError,
                  case .failedToFindRuuviTag = persistenceError else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testPerformMapsLocalError() async {
        do {
            _ = try await RuuviServiceError.perform {
                throw RuuviLocalError.failedToGetDocumentsDirectory
            }
            XCTFail("Expected perform to throw")
        } catch let error as RuuviServiceError {
            guard case let .ruuviLocal(localError) = error,
                  case .failedToGetDocumentsDirectory = localError else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testPerformWrapsUnknownErrorAsNetworkingError() async {
        do {
            _ = try await RuuviServiceError.perform {
                throw TestError.sample
            }
            XCTFail("Expected perform to throw")
        } catch let error as RuuviServiceError {
            guard case let .networking(underlyingError) = error,
                  let wrapped = underlyingError as? TestError,
                  wrapped == .sample else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testAsyncOperationStartsExecutingBeforeMainRuns() {
        let expectation = expectation(description: #function)
        let operation = InspectingAsyncOperation()

        operation.onMain = {
            XCTAssertTrue(operation.isExecuting)
            XCTAssertEqual(operation.state, .executing)
            operation.state = .finished
            expectation.fulfill()
        }

        operation.start()

        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(operation.isFinished)
        XCTAssertTrue(operation.didRunMain)
    }

    func testCancelledAsyncOperationFinishesWithoutRunningMain() {
        let operation = InspectingAsyncOperation()

        operation.cancel()
        operation.start()

        XCTAssertTrue(operation.isFinished)
        XCTAssertFalse(operation.didRunMain)
    }

    func testOptionalUserDefaultsHelpersHandleMissingStoredAndMismatchedValues() {
        let suffix = UUID().uuidString
        let intKey = "RuuviServiceTests.int.\(suffix)"
        let doubleKey = "RuuviServiceTests.double.\(suffix)"
        let boolKey = "RuuviServiceTests.bool.\(suffix)"
        defer {
            UserDefaults.standard.removeObject(forKey: intKey)
            UserDefaults.standard.removeObject(forKey: doubleKey)
            UserDefaults.standard.removeObject(forKey: boolKey)
        }

        XCTAssertNil(UserDefaults.standard.optionalInt(forKey: intKey))
        XCTAssertNil(UserDefaults.standard.optionalDouble(forKey: doubleKey))
        XCTAssertNil(UserDefaults.standard.optionalBool(forKey: boolKey))

        UserDefaults.standard.set("not-an-int", forKey: intKey)
        UserDefaults.standard.set("not-a-double", forKey: doubleKey)
        UserDefaults.standard.set("not-a-bool", forKey: boolKey)

        XCTAssertNil(UserDefaults.standard.optionalInt(forKey: intKey))
        XCTAssertNil(UserDefaults.standard.optionalDouble(forKey: doubleKey))
        XCTAssertNil(UserDefaults.standard.optionalBool(forKey: boolKey))

        UserDefaults.standard.set(240, forKey: intKey)
        UserDefaults.standard.set(60.5, forKey: doubleKey)
        UserDefaults.standard.set(true, forKey: boolKey)

        XCTAssertEqual(UserDefaults.standard.optionalInt(forKey: intKey), 240)
        XCTAssertEqual(UserDefaults.standard.optionalDouble(forKey: doubleKey), 60.5)
        XCTAssertEqual(UserDefaults.standard.optionalBool(forKey: boolKey), true)
    }
}

private enum TestError: Error, Equatable {
    case sample
}

private final class InspectingAsyncOperation: AsyncOperation, @unchecked Sendable {
    var didRunMain = false
    var onMain: (() -> Void)?

    override func main() {
        didRunMain = true
        onMain?()
    }
}
