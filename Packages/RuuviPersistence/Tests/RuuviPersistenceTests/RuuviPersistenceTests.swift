import Foundation
import Testing
import RuuviContext
import RuuviOntology
@testable import RuuviPersistence
#if SWIFT_PACKAGE
    import RuuviContextSQLite
    @testable import RuuviPersistenceSQLite
#endif

struct RuuviPersistenceTests {
    @Test func queuedRequestUpsertIncrementsAttemptsAndKeepsIdentity() async throws {
        let fixture = try DatabaseFixture()
        defer { fixture.close() }
        _ = try await fixture.store.createQueuedRequest(request(attempts: 4, body: "first"))
        let first = try await fixture.store.readQueuedRequests()
        _ = try await fixture.store.createQueuedRequest(request(attempts: 0, body: "second"))
        let updated = try await fixture.store.readQueuedRequests()
        #expect(updated.count == 1)
        #expect(updated.first?.id == first.first?.id)
        #expect(updated.first?.attempts == 5)
        #expect(updated.first?.requestBodyData == Data("second".utf8))
    }

    @Test func concurrentQueueWritesDoNotCreateDuplicates() async throws {
        let fixture = try DatabaseFixture()
        defer { fixture.close() }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask { _ = try await fixture.store.createQueuedRequest(request()) }
            }
            try await group.waitForAll()
        }
        let requests = try await fixture.store.readQueuedRequests()
        #expect(requests.count == 1)
        #expect(requests.first?.attempts == 19)
    }

    @Test func requestTypeParticipatesInQueueIdentity() async throws {
        let fixture = try DatabaseFixture()
        defer { fixture.close() }
        _ = try await fixture.store.createQueuedRequest(request(type: .sensor))
        _ = try await fixture.store.createQueuedRequest(request(type: .settings))
        let requests = try await fixture.store.readQueuedRequests()
        #expect(requests.count == 2)
        _ = try await fixture.store.deleteQueuedRequest(try #require(requests.first))
        #expect(try await fixture.store.readQueuedRequests().count == 1)
        _ = try await fixture.store.deleteQueuedRequests()
        #expect(try await fixture.store.readQueuedRequests().isEmpty)
    }

    @Test func settingsPreserveRawValuesAndUpdateInsteadOfDuplicating() async throws {
        let fixture = try DatabaseFixture()
        defer { fixture.close() }
        let date = Date(timeIntervalSince1970: 12345)
        _ = try await fixture.store.save(
            userSetting: RuuviUserSettingStruct(key: "unit", value: "unknown-future-unit", lastUpdated: date))
        let stored = try await fixture.store.readUserSetting(for: "unit")
        #expect(stored?.value == "unknown-future-unit")
        #expect(stored?.lastUpdated == date)
        _ = try await fixture.store.save(userSetting: RuuviUserSettingStruct(key: "unit", value: "celsius"))
        #expect(try await fixture.store.readUserSettings().count == 1)
        #expect(try await fixture.store.readUserSetting(for: "missing") == nil)
        _ = try await fixture.store.deleteUserSettings()
        #expect(try await fixture.store.readUserSettings().isEmpty)
    }

    @Test func settingsBatchIsVisibleWhenAwaitReturns() async throws {
        let fixture = try DatabaseFixture()
        defer { fixture.close() }
        _ = try await fixture.store.save(userSettings: [
            RuuviUserSettingStruct(key: "b", value: "2"),
            RuuviUserSettingStruct(key: "a", value: "1"),
        ])
        #expect(try await fixture.store.readUserSettings().map(\.key) == ["a", "b"])
    }

    private func request(attempts: Int = 0, body: String = "payload", type: RuuviCloudQueuedRequestType = .sensor)
        -> RuuviCloudQueuedRequestStruct
    {
        .init(
            id: nil, type: type, status: .failed, uniqueKey: "sensor-id", requestDate: Date(), successDate: nil,
            attempts: attempts, requestBodyData: Data(body.utf8), additionalData: nil)
    }
}

private struct DatabaseFixture {
    let directory: URL
    let store: RuuviPersistenceSQLite
    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let context = try SQLiteContextFactoryGRDB().create(at: directory.appendingPathComponent("test.sqlite"))
        store = RuuviPersistenceSQLite(context: context)
    }
    func close() { try? FileManager.default.removeItem(at: directory) }
}
