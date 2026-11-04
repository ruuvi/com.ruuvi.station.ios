import Foundation
import XCTest
import RuuviAnalytics
import RuuviContext
import RuuviOntology
import RuuviPersistence
@testable import RuuviReactor
#if SWIFT_PACKAGE
    import RuuviContextSQLite
    import RuuviPersistenceSQLite
    @testable import RuuviReactorImpl
#endif

final class RuuviReactorTests: XCTestCase {
    @MainActor func testInitialInsertUpdateDeleteAreOrderedAndCancellationStopsDelivery() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let context = try SQLiteContextFactoryGRDB().create(at: directory.appendingPathComponent("test.sqlite"))
        let persistence = RuuviPersistenceSQLite(context: context)
        let reactor = RuuviReactorFactoryImpl().create(
            sqliteContext: context, sqlitePersistence: persistence, errorReporter: Reporter())
        let initial = expectation(description: "Initial empty snapshot")
        let insert = expectation(description: "Insert")
        let update = expectation(description: "Update")
        let delete = expectation(description: "Delete")
        var changes = [String]()
        let token = reactor.observe { change in
            XCTAssertTrue(Thread.isMainThread)
            switch change {
            case .initial(let values): XCTAssertTrue(values.isEmpty); changes.append("initial"); initial.fulfill()
            case .insert(let sensor): XCTAssertEqual(sensor.name, "first"); changes.append("insert"); insert.fulfill()
            case .update(let sensor): XCTAssertEqual(sensor.name, "second"); changes.append("update"); update.fulfill()
            case .delete: changes.append("delete"); delete.fulfill()
            case .error(let error): XCTFail("Unexpected observation error: \(error)")
            }
        }
        defer { token.invalidate() }
        await fulfillment(of: [initial], timeout: 3)
        let sensor = RuuviTagSensorStruct(
            version: 5, firmwareVersion: nil, luid: nil,
            macId: "AA:BB:CC:DD:EE:FF".mac, serviceUUID: nil, isConnectable: false, name: "first",
            isClaimed: false, isOwner: true, owner: nil, ownersPlan: nil, isCloudSensor: false,
            canShare: false, sharedTo: [], maxHistoryDays: nil)
        _ = try await persistence.create(sensor)
        await fulfillment(of: [insert], timeout: 3)
        _ = try await persistence.update(sensor.with(name: "second"))
        await fulfillment(of: [update], timeout: 3)
        _ = try await persistence.delete(sensor)
        await fulfillment(of: [delete], timeout: 3)
        XCTAssertEqual(changes, ["initial", "insert", "update", "delete"])
        token.invalidate()
        _ = try await persistence.create(sensor)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(changes.count, 4)
    }
}

private final class Reporter: RuuviErrorReporter {
    func report(error: Error) { XCTFail("Unexpected database error: \(error)") }
}
