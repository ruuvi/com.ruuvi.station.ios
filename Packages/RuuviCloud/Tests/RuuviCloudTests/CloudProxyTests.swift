import Foundation
import Testing
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviUser
@testable import RuuviCloud
#if SWIFT_PACKAGE
    import RuuviCloudApi
    import RuuviCloudPure
#endif

@MainActor func makeCloudService(api: RuuviCloudApi, user: RuuviUser, pool: RuuviPool?) -> RuuviCloud {
    RuuviCloudCanonicalProxy(cloud: RuuviCloudPure(api: api, user: user, pool: pool), localIDs: CloudMemoryIDs())
}

extension CloudTransportTests {
    @MainActor @Test func canonicalIdentifiersAreSentToCloudAndRestoredForLocalCallers() async throws {
        let full = "AA:BB:CC:DD:EE:FF"
        let short = "CC:DD:EE:FF"
        let transport = TransportFixture(status: 200, body: cloudSuccess("{\"sensor\":\"\(full)\",\"invited\":true}"))
        defer { transport.close() }
        let ids = CloudMemoryIDs()
        ids.set(fullMac: full.mac, for: short.mac)
        let service = RuuviCloudCanonicalProxy(
            cloud: RuuviCloudPure(api: transport.api, user: CloudTestUser(), pool: nil), localIDs: ids)
        #expect(try await service.claim(name: "Sauna", macId: short.mac)?.value == short)
        try assertCloudRequest(path: "/claim", body: ["sensor": full])
        #expect(try await service.contest(macId: short.mac, secret: "secret")?.value == short)
        try assertCloudRequest(path: "/contest-sensor", body: ["sensor": full])
        #expect(try await service.unclaim(macId: short.mac, removeCloudHistory: false).value == short)
        try assertCloudRequest(path: "/unclaim", body: ["sensor": full])
        #expect(try await service.unshare(macId: short.mac, with: nil).value == short)
        try assertCloudRequest(path: "/unshare", body: ["sensor": full])
        #expect(try await service.share(macId: short.mac, with: "guest@example.com").macId?.value == short)
        try assertCloudRequest(path: "/share", body: ["sensor": full])
        let sensor = cloudTestSensor().with(macId: short.mac)
        #expect(try await service.update(name: "New name", for: sensor).macId?.value == short)
        try assertCloudRequest(path: "/update", body: ["sensor": full, "name": "New name"])
        #expect(
            try await service.update(temperatureOffset: 1, humidityOffset: nil, pressureOffset: nil, for: sensor).macId?
                .value == short)
        try assertCloudRequest(path: "/update", body: ["sensor": full, "offsetTemperature": 1])
        #expect(
            try await service.updateSensorSettings(
                for: sensor, types: ["description"], values: ["Note"], timestamp: 123
            ).macId?.value == short)
        try assertCloudRequest(path: "/sensor-settings", body: ["sensor": full, "value": ["Note"]])
        try await service.resetImage(for: short.mac)
        try assertCloudRequest(path: "/upload", body: ["sensor": full, "action": "reset"])
        setCloudResponse("{}")
        #expect(try await service.share(macId: short.mac, with: "guest@example.com").macId?.value == short)
        #expect(try await service.loadShared(for: sensor).isEmpty)
        try assertCloudRequest(path: "/sensors", query: ["sensor": full])
        #expect(
            try await service.loadSensorsDense(
                for: sensor, measurements: false, sharedToOthers: nil, sharedToMe: nil,
                alerts: false, settings: true
            ).isEmpty)
        try assertCloudRequest(path: "/sensors-dense", query: ["sensor": full])
        var localOnly = cloudTestSensor()
        localOnly.macId = nil
        localOnly.luid = UUID().uuidString.luid
        let returned = try await service.update(name: "Local only", for: localOnly)
        #expect(returned.macId == nil && returned.luid?.value == localOnly.luid?.value)
        try assertCloudRequest(path: "/update", body: ["sensor": localOnly.id])
    }
}

final class CloudMemoryIDs: RuuviLocalIDs {
    private var canonical: [String: String] = [:]
    func fullMac(for mac: MACIdentifier) -> MACIdentifier? { canonical[mac.value]?.mac }
    func originalMac(for fullMac: MACIdentifier) -> MACIdentifier? {
        canonical.first { $0.value == fullMac.value }?.key.mac
    }
    func set(fullMac: MACIdentifier, for mac: MACIdentifier) { canonical[mac.value] = fullMac.value }
    func removeFullMac(for mac: MACIdentifier) { canonical[mac.value] = nil }
    func mac(for luid: LocalIdentifier) -> MACIdentifier? { nil }
    func set(mac: MACIdentifier, for luid: LocalIdentifier) {}
    func luid(for mac: MACIdentifier) -> LocalIdentifier? { nil }
    func extendedLuid(for mac: MACIdentifier) -> LocalIdentifier? { nil }
    func set(luid: LocalIdentifier, for mac: MACIdentifier) {}
    func set(extendedLuid: LocalIdentifier, for mac: MACIdentifier) {}
}
