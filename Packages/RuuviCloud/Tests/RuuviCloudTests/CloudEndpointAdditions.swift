import Foundation
import Testing
import RuuviOntology
@testable import RuuviCloud
#if SWIFT_PACKAGE
    import RuuviCloudApi
    import RuuviCloudPure
#endif

extension CloudTransportTests {
    @MainActor @Test func alertAndRenameNotificationsDescribeSuccessAndFailureInOrder() async throws {
        let transport = TransportFixture(status: 200, body: #"{"result":"success","data":{}}"#)
        defer { transport.close() }
        let user = CloudTestUser()
        let service = makeCloudService(api: transport.api, user: user, pool: nil)
        let sensor = cloudTestSensor()
        let events = CloudRequestEvents()
        let observer = NotificationCenter.default.addObserver(
            forName: .RuuviCloudRequestStateDidChange, object: nil, queue: nil
        ) { event in
            events.append(event)
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        try await service.setAlert(
            type: .temperature, settingType: .upperBound, isEnabled: true, min: -10,
            max: 30, counter: 7, delay: 60, description: "Sauna alert", for: sensor.macId!)
        #expect(events.states == [.loading, .success, .complete])
        #expect(events.ids == [sensor.id, sensor.id, sensor.id])
        try assertCloudRequest(
            path: "/alerts",
            body: [
                "sensor": sensor.id, "enabled": true, "type": "temperature",
                "min": -10, "max": 30, "counter": 7, "delay": 60, "description": "Sauna alert",
            ])
        events.clear()
        TransportProtocol.state.configure(status: 503, data: Data(), error: nil, pending: false)
        do { _ = try await service.update(name: "New", for: sensor); Issue.record("Failed rename succeeded") } catch {}
        #expect(events.states == [.loading, .failed, .complete])
        events.clear()
        user.logout()
        do { _ = try await service.update(name: "New", for: sensor); Issue.record("Signed out rename succeeded") } catch
        {}
        #expect(events.states == [.loading, .failed])
    }

    @MainActor @Test func denseSensorDecodingPreservesCapabilitiesSettingsAndCaseInsensitiveOwnership() async throws {
        let payload =
            #"""
            {
              "sensors": [
                {
                  "sensor": "AA:BB:CC:DD:EE:FF",
                  "owner": "TEST@EXAMPLE.COM",
                  "name": "Sauna",
                  "picture": "https://example.com/photo",
                  "public": false,
                  "canShare": true,
                  "offsetTemperature": 1,
                  "offsetHumidity": 10,
                  "offsetPressure": 200,
                  "sharedTo": [
                    "guest@example.com"
                  ],
                  "sharedToPending": [
                    "invited@example.com"
                  ],
                  "lastUpdated": 1700000000,
                  "settings": {
                    "displayOrder": [
                      "TEMPERATURE_F"
                    ],
                    "defaultDisplayOrder": false
                  }
                }
              ]
            }
            """#
        let transport = TransportFixture(status: 200, body: cloudSuccess(payload))
        defer { transport.close() }
        let service = makeCloudService(api: transport.api, user: CloudTestUser(), pool: nil)
        let sensors = try await service.loadSensorsDense(
            for: cloudTestSensor(), measurements: true, sharedToOthers: true,
            sharedToMe: false, alerts: true, settings: true)
        let dense = try #require(sensors.first)
        #expect(dense.sensor.isOwner && dense.sensor.isClaimed && dense.sensor.canShare)
        #expect(dense.sensor.owner == "test@example.com")
        #expect(dense.sensor.sharedTo == ["guest@example.com"])
        #expect(dense.sensor.sharedToPending == ["invited@example.com"])
        #expect(
            dense.sensor.offsetTemperature == 1 && dense.sensor.offsetHumidity == 10
                && dense.sensor.offsetPressure == 200)
        #expect(dense.sensor.lastUpdated == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(dense.record == nil && dense.alerts.alerts?.isEmpty == true)
        #expect(dense.settings?.displayOrderCodes == ["TEMPERATURE_F"])
        #expect(dense.settings?.defaultDisplayOrder == false)
        try assertCloudRequest(
            path: "/sensors-dense",
            query: [
                "sensor": "AA:BB:CC:DD:EE:FF", "measurements": "true",
                "sharedToOthers": "true", "sharedToMe": "false",
                "alerts": "true", "settings": "true",
            ])
    }
}

private final class CloudRequestEvents: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [(RuuviCloudRequestStateType, String)] = []
    var states: [RuuviCloudRequestStateType] { lock.withLock { values.map(\.0) } }
    var ids: [String] { lock.withLock { values.map(\.1) } }
    func clear() { lock.withLock { values.removeAll() } }
    func append(_ event: Notification) {
        guard let state = event.userInfo?[RuuviCloudRequestStateKey.state] as? RuuviCloudRequestStateType,
            let id = event.userInfo?[RuuviCloudRequestStateKey.macId] as? String
        else { return }
        lock.withLock { values.append((state, id)) }
    }
}

extension CloudTransportTests {
    @MainActor @Test func cloudSettingsDecodeScalarsWithoutOverflowAndIgnoreInvalidDates() async throws {
        let transport = TransportFixture(
            status: 200,
            body: cloudSuccess(
                #"""
                {"settings": {
                  "UNIT_TEMPERATURE": "F",
                  "ACCURACY_TEMPERATURE": 2,
                  "ACCURACY_HUMIDITY": 1.5,
                  "CHART_SHOW_ALL_POINTS": true,
                  "CHART_VIEW_PERIOD": 1e100,
                  "ACCURACY_PM": null,
                  "ACCURACY_VOLTAGE": [1,2],
                  "PROFILE_LANGUAGE_CODE": "FI",
                  "UNIT_TEMPERATURE_lastUpdated": 1700000000,
                  "ACCURACY_HUMIDITY_lastUpdated": "1700000000.5",
                  "PROFILE_LANGUAGE_CODE_lastUpdated": "nan",
                  "UNIT_PRESSURE_lastUpdated": "inf",
                  "unknown": "ignored",
                  "unknown_lastUpdated": 1700000000
                }}
                """#))
        defer { transport.close() }
        let service = makeCloudService(api: transport.api, user: CloudTestUser(), pool: nil)
        let settings = try #require(try await service.getCloudSettings())
        #expect(settings.userSettingValue(for: .unitTemperature) == "F")
        #expect(settings.userSettingValue(for: .accuracyTemperature) == "2")
        #expect(settings.userSettingValue(for: .accuracyHumidity) == "1.5")
        #expect(settings.userSettingValue(for: .chartShowAllPoints) == "true")
        #expect(settings.userSettingValue(for: .chartViewPeriod) == "1e+100")
        #expect(settings.userSettingValue(for: .accuracyPM) == nil)
        #expect(settings.userSettingValue(for: .accuracyVoltage) == nil)
        let dates = Dictionary(
            settings.userSettings.map { ($0.key, $0.lastUpdated) }, uniquingKeysWith: { _, last in last })
        #expect(dates["UNIT_TEMPERATURE"]! == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(dates["ACCURACY_HUMIDITY"]! == Date(timeIntervalSince1970: 1_700_000_000.5))
        #expect(dates["PROFILE_LANGUAGE_CODE"]! == nil)
        #expect(settings.userSettings.allSatisfy { $0.key != "unknown" })
        try assertCloudRequest(path: "/settings", query: [:])
    }

    @MainActor @Test func invalidNumericWritesFailBeforeHTTPAndPublicAccountEndpointsPreserveErrors() async throws {
        let transport = TransportFixture(status: 503, body: "Unavailable")
        defer { transport.close() }
        let service = makeCloudService(api: transport.api, user: CloudTestUser(), pool: nil)
        do {
            _ = try await service.update(
                temperatureOffset: .nan, humidityOffset: nil, pressureOffset: nil, for: cloudTestSensor())
            Issue.record("Nonfinite calibration accepted")
        } catch { guard case .api(.badParameters) = error else { Issue.record("Unexpected error \(error)"); return } }
        #expect(TransportProtocol.state.requests.isEmpty)
        do {
            _ = try await service.requestCode(email: "test@example.com"); Issue.record("Offline registration succeeded")
        } catch {
            guard case .api(.unexpectedHTTPStatusCodeShouldRetry(503)) = error else { Issue.record("\(error)"); return }
        }
        do { _ = try await service.validateCode(code: "code"); Issue.record("Offline verification succeeded") } catch {
            guard case .api(.unexpectedHTTPStatusCodeShouldRetry(503)) = error else { Issue.record("\(error)"); return }
        }
        do {
            _ = try await service.unregisterPNToken(token: "token", tokenId: nil);
            Issue.record("Offline unregister succeeded")
        } catch {
            guard case .api(.unexpectedHTTPStatusCodeShouldRetry(503)) = error else { Issue.record("\(error)"); return }
        }
    }
}
