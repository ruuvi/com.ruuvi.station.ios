@testable import RuuviCloud
import Foundation
import RuuviOntology
import XCTest

final class RuuviCloudRequestResponseCoverageTests: XCTestCase {
    func testRequestModelsEncodeExpectedPayloads() throws {
        var getAlerts = RuuviCloudApiGetAlertsRequest()
        getAlerts.sensor = "AA:BB:CC:11:22:33"

        let payloads: [(String, Any)] = [
            (
                "account delete",
                try jsonObject(
                    from: RuuviCloudApiAccountDeleteRequest(email: "owner@example.com")
                )
            ),
            (
                "contest",
                try jsonObject(
                    from: RuuviCloudApiContestRequest(
                        sensor: "AA:BB:CC:11:22:33",
                        secret: "secret"
                    )
                )
            ),
            ("get alerts", try jsonObject(from: getAlerts)),
            (
                "get settings",
                try jsonObject(from: RuuviCloudApiGetSettingsRequest())
            ),
            (
                "get sensors dense",
                try jsonObject(
                    from: RuuviCloudApiGetSensorsDenseRequest(
                        sensor: "AA:BB:CC:11:22:33",
                        measurements: true,
                        sharedToMe: false,
                        sharedToOthers: true,
                        alerts: true,
                        settings: false
                    )
                )
            ),
            (
                "post alert",
                try jsonObject(
                    from: RuuviCloudApiPostAlertRequest(
                        sensor: "AA:BB:CC:11:22:33",
                        enabled: true,
                        type: .temperature,
                        min: -5,
                        max: 20,
                        description: "Room",
                        counter: 3,
                        delay: 15,
                        timestamp: 123
                    )
                )
            ),
            (
                "post sensor settings",
                try jsonObject(
                    from: RuuviCloudApiPostSensorSettingsRequest(
                        sensor: "AA:BB:CC:11:22:33",
                        type: ["description", "displayOrder"],
                        value: ["Room", "[\"temperature\"]"],
                        timestamp: 456
                    )
                )
            ),
            (
                "unclaim",
                try jsonObject(
                    from: RuuviCloudApiUnclaimRequest(
                        sensor: "AA:BB:CC:11:22:33",
                        deleteData: true
                    )
                )
            ),
            (
                "verify",
                try jsonObject(from: RuuviCloudApiVerifyRequest(token: "token"))
            ),
            (
                "user request",
                try jsonObject(from: RuuviCloudApiUserRequest())
            ),
            (
                "pn list",
                try jsonObject(from: RuuviCloudPNTokenListRequest())
            ),
            (
                "pn register",
                try jsonObject(
                    from: RuuviCloudPNTokenRegisterRequest(
                        token: "apns-token",
                        type: "ios",
                        name: "Phone",
                        data: "payload",
                        params: [
                            RuuviCloudPNTokenRegisterRequestParamsKey.language.rawValue: "en",
                            RuuviCloudPNTokenRegisterRequestParamsKey.sound.rawValue: "beep.aiff",
                        ]
                    )
                )
            ),
            (
                "pn unregister",
                try jsonObject(
                    from: RuuviCloudPNTokenUnregisterRequest(token: "apns-token", id: 7)
                )
            ),
        ]

        XCTAssertEqual(payloads.count, 13)

        let accountDelete = try XCTUnwrap(payloads.first { $0.0 == "account delete" }?.1 as? [String: Any])
        XCTAssertEqual(accountDelete["email"] as? String, "owner@example.com")

        let contest = try XCTUnwrap(payloads.first { $0.0 == "contest" }?.1 as? [String: Any])
        XCTAssertEqual(contest["sensor"] as? String, "AA:BB:CC:11:22:33")
        XCTAssertEqual(contest["secret"] as? String, "secret")

        let alerts = try XCTUnwrap(payloads.first { $0.0 == "get alerts" }?.1 as? [String: Any])
        XCTAssertEqual(alerts["sensor"] as? String, "AA:BB:CC:11:22:33")

        let getSettings = try XCTUnwrap(payloads.first { $0.0 == "get settings" }?.1 as? [String: Any])
        XCTAssertTrue(getSettings.isEmpty)

        let dense = try XCTUnwrap(payloads.first { $0.0 == "get sensors dense" }?.1 as? [String: Any])
        XCTAssertEqual(dense["sensor"] as? String, "AA:BB:CC:11:22:33")
        XCTAssertEqual(dense["measurements"] as? Bool, true)
        XCTAssertEqual(dense["sharedToMe"] as? Bool, false)
        XCTAssertEqual(dense["sharedToOthers"] as? Bool, true)
        XCTAssertEqual(dense["alerts"] as? Bool, true)
        XCTAssertEqual(dense["settings"] as? Bool, false)

        let postAlert = try XCTUnwrap(payloads.first { $0.0 == "post alert" }?.1 as? [String: Any])
        XCTAssertEqual(postAlert["sensor"] as? String, "AA:BB:CC:11:22:33")
        XCTAssertEqual(postAlert["enabled"] as? Bool, true)
        XCTAssertEqual(postAlert["type"] as? String, "temperature")
        XCTAssertEqual(postAlert["min"] as? Double, -5)
        XCTAssertEqual(postAlert["max"] as? Double, 20)
        XCTAssertEqual(postAlert["description"] as? String, "Room")
        XCTAssertEqual(postAlert["counter"] as? Int, 3)
        XCTAssertEqual(postAlert["delay"] as? Int, 15)
        XCTAssertEqual(postAlert["timestamp"] as? Int, 123)

        let postSensorSettings = try XCTUnwrap(
            payloads.first { $0.0 == "post sensor settings" }?.1 as? [String: Any]
        )
        XCTAssertEqual(postSensorSettings["sensor"] as? String, "AA:BB:CC:11:22:33")
        XCTAssertEqual(postSensorSettings["type"] as? [String], ["description", "displayOrder"])
        XCTAssertEqual(postSensorSettings["value"] as? [String], ["Room", "[\"temperature\"]"])
        XCTAssertEqual(postSensorSettings["timestamp"] as? Int, 456)

        let unclaim = try XCTUnwrap(payloads.first { $0.0 == "unclaim" }?.1 as? [String: Any])
        XCTAssertEqual(unclaim["sensor"] as? String, "AA:BB:CC:11:22:33")
        XCTAssertEqual(unclaim["deleteData"] as? Bool, true)

        let verify = try XCTUnwrap(payloads.first { $0.0 == "verify" }?.1 as? [String: Any])
        XCTAssertEqual(verify["token"] as? String, "token")

        let userRequest = try XCTUnwrap(payloads.first { $0.0 == "user request" }?.1 as? [String: Any])
        XCTAssertTrue(userRequest.isEmpty)

        let pnList = try XCTUnwrap(payloads.first { $0.0 == "pn list" }?.1 as? [String: Any])
        XCTAssertTrue(pnList.isEmpty)

        let pnRegister = try XCTUnwrap(payloads.first { $0.0 == "pn register" }?.1 as? [String: Any])
        XCTAssertEqual(pnRegister["token"] as? String, "apns-token")
        XCTAssertEqual(pnRegister["type"] as? String, "ios")
        XCTAssertEqual(pnRegister["name"] as? String, "Phone")
        XCTAssertEqual(pnRegister["data"] as? String, "payload")
        let params = try XCTUnwrap(pnRegister["params"] as? [String: String])
        XCTAssertEqual(params["language"], "en")
        XCTAssertEqual(params["soundFile"], "beep.aiff")

        let pnUnregister = try XCTUnwrap(payloads.first { $0.0 == "pn unregister" }?.1 as? [String: Any])
        XCTAssertEqual(pnUnregister["token"] as? String, "apns-token")
        XCTAssertEqual(pnUnregister["id"] as? Int, 7)
    }

    func testResponseModelsDecodeAndMapDerivedProperties() throws {
        let ownerResponse = try JSONDecoder().decode(
            RuuviCloudAPICheckOwnerResponse.self,
            from: """
            { "email": "owner@example.com", "sensor": "AA:BB:CC:11:22:33" }
            """.data(using: .utf8)!
        )
        let accountDelete = try JSONDecoder().decode(
            RuuviCloudApiAccountDeleteResponse.self,
            from: """
            { "email": "owner@example.com" }
            """.data(using: .utf8)!
        )
        let contest = try JSONDecoder().decode(
            RuuviCloudApiContestResponse.self,
            from: """
            { "sensor": "AA:BB:CC:11:22:33" }
            """.data(using: .utf8)!
        )
        let getSensor = try JSONDecoder().decode(
            RuuviCloudApiGetSensorResponse.self,
            from: """
            {
              "sensor": "AA:BB:CC:11:22:33",
              "total": 1,
              "name": "Garage",
              "measurements": [{
                "gwmac": "11:22:33:44:55:66",
                "coordinates": "1,2",
                "rssi": -70,
                "timestamp": 1700000000,
                "data": "payload"
              }]
            }
            """.data(using: .utf8)!
        )
        let dense = try JSONDecoder().decode(
            RuuviCloudApiGetSensorsDenseResponse.self,
            from: """
            {
              "sensors": [{
                "sensor": "AA:BB:CC:11:22:33",
                "owner": "owner@example.com",
                "name": "Office",
                "picture": "https://example.com/picture.png",
                "public": true,
                "canShare": true,
                "offsetTemperature": 1.5,
                "offsetHumidity": 12,
                "offsetPressure": 450,
                "sharedTo": ["friend@example.com"],
                "measurements": [{
                  "gwmac": "11:22:33:44:55:66",
                  "coordinates": "1,2",
                  "rssi": -65,
                  "timestamp": 1700000001,
                  "data": "payload"
                }],
                "alerts": [{
                  "type": "humidity",
                  "enabled": true,
                  "min": 1,
                  "max": 2,
                  "counter": 3,
                  "delay": 4,
                  "description": "Air",
                  "triggered": true,
                  "triggeredAt": "2024-01-01T00:00:00Z",
                  "lastUpdated": 1700000000
                }],
                "subscription": {
                  "macId": "AA:BB:CC:11:22:33",
                  "subscriptionName": "pro",
                  "isActive": true,
                  "maxClaims": 10
                },
                "settings": {
                  "displayOrder": "[\\"temperature\\",\\"humidity\\"]",
                  "defaultDisplayOrder": "true",
                  "displayOrder_lastUpdated": 1700000002,
                  "defaultDisplayOrder_lastUpdated": 1700000003,
                  "description": "Office sensor",
                  "description_lastUpdated": 1700000004
                },
                "lastUpdated": 1700000005
              }]
            }
            """.data(using: .utf8)!
        )
        let sensors = try JSONDecoder().decode(
            RuuviCloudApiGetSensorsResponse.self,
            from: """
            {
              "sensors": [{
                "sensor": "AA:BB:CC:11:22:33",
                "name": "Office",
                "picture": "https://example.com/picture.png",
                "public": true,
                "canShare": true,
                "sharedTo": ["friend@example.com"]
              }]
            }
            """.data(using: .utf8)!
        )
        let postSensorSettings = try JSONDecoder().decode(
            RuuviCloudApiPostSensorSettingsResponse.self,
            from: """
            { "result": "success", "data": { "action": "saved" } }
            """.data(using: .utf8)!
        )
        let register = try JSONDecoder().decode(
            RuuviCloudApiRegisterResponse.self,
            from: """
            { "email": "owner@example.com" }
            """.data(using: .utf8)!
        )
        let update = try JSONDecoder().decode(
            RuuviCloudApiSensorUpdateResponse.self,
            from: """
            { "name": "Updated name" }
            """.data(using: .utf8)!
        )
        let share = try JSONDecoder().decode(
            RuuviCloudApiShareResponse.self,
            from: """
            { "sensor": "AA:BB:CC:11:22:33", "invited": true }
            """.data(using: .utf8)!
        )
        let user = try JSONDecoder().decode(
            RuuviCloudApiUserResponse.self,
            from: """
            {
              "email": "owner@example.com",
              "sensors": [{
                "sensor": "AA:BB:CC:11:22:33",
                "owner": "owner@example.com",
                "picture": "https://example.com/picture.png",
                "name": "Office",
                "public": true,
                "offsetTemperature": 1.5,
                "offsetHumidity": 12,
                "offsetPressure": 450
              }]
            }
            """.data(using: .utf8)!
        )
        let verify = try JSONDecoder().decode(
            RuuviCloudApiVerifyResponse.self,
            from: """
            { "email": "owner@example.com", "accessToken": "token", "newUser": true }
            """.data(using: .utf8)!
        )
        let pnRegister = try JSONDecoder().decode(
            RuuviCloudPNTokenRegisterResponse.self,
            from: """
            { "id": 7, "lastAccessed": 1700000000, "name": "Phone" }
            """.data(using: .utf8)!
        )
        let postAlert = try JSONDecoder().decode(
            RuuviCloudApiPostAlertResponse.self,
            from: """
            { "action": "ok" }
            """.data(using: .utf8)!
        )

        XCTAssertEqual(ownerResponse.email, "owner@example.com")
        XCTAssertEqual(ownerResponse.sensor, "AA:BB:CC:11:22:33")
        XCTAssertEqual(accountDelete.email, "owner@example.com")
        XCTAssertEqual(contest.sensor, "AA:BB:CC:11:22:33")
        XCTAssertEqual(getSensor.sensor, "AA:BB:CC:11:22:33")
        XCTAssertEqual(getSensor.total, 1)
        XCTAssertEqual(getSensor.name, "Garage")
        XCTAssertEqual(getSensor.measurements?.first?.date.timeIntervalSince1970, 1_700_000_000)

        let denseSensor = try XCTUnwrap(dense.sensors?.first)
        XCTAssertEqual(denseSensor.lastMeasurement?.timestamp, 1_700_000_001)
        XCTAssertEqual(denseSensor.lastUpdatedDate?.timeIntervalSince1970, 1_700_000_005)
        XCTAssertEqual(denseSensor.alerts.alerts?.first?.description, "Air")
        XCTAssertEqual(denseSensor.subscription?.subscriptionName, "pro")
        let settings = try XCTUnwrap(denseSensor.settings)
        XCTAssertEqual(settings.displayOrderCodes, ["temperature", "humidity"])
        XCTAssertEqual(settings.defaultDisplayOrder, true)
        XCTAssertEqual(settings.displayOrderLastUpdatedDate?.timeIntervalSince1970, 1_700_000_002)
        XCTAssertEqual(
            settings.defaultDisplayOrderLastUpdatedDate?.timeIntervalSince1970,
            1_700_000_003
        )
        XCTAssertEqual(settings.description, "Office sensor")
        XCTAssertEqual(settings.descriptionLastUpdatedDate?.timeIntervalSince1970, 1_700_000_004)

        let shareable = try XCTUnwrap(sensors.sensors?.first?.shareableSensor)
        XCTAssertEqual(shareable.id, "AA:BB:CC:11:22:33")
        XCTAssertEqual(shareable.canShare, true)
        XCTAssertEqual(shareable.sharedTo, ["friend@example.com"])

        XCTAssertEqual(postSensorSettings.result, "success")
        XCTAssertEqual(postSensorSettings.data?.action, "saved")
        XCTAssertEqual(register.email, "owner@example.com")
        XCTAssertEqual(update.name, "Updated name")
        XCTAssertEqual(share.sensor, "AA:BB:CC:11:22:33")
        XCTAssertEqual(share.invited, true)
        XCTAssertEqual(user.email, "owner@example.com")
        XCTAssertEqual(user.sensors.first?.id, "AA:BB:CC:11:22:33")
        XCTAssertEqual(user.sensors.first?.owner, "owner@example.com")
        XCTAssertEqual(user.sensors.first?.picture?.absoluteString, "https://example.com/picture.png")
        XCTAssertEqual(user.sensors.first?.offsetTemperature, 1.5)
        XCTAssertEqual(user.sensors.first?.offsetHumidity, 0.12)
        XCTAssertEqual(user.sensors.first?.offsetPressure, 4.5)
        XCTAssertEqual(user.sensors.first?.isCloudSensor, true)
        XCTAssertEqual(verify.email, "owner@example.com")
        XCTAssertEqual(verify.accessToken, "token")
        XCTAssertEqual(verify.isNewUser, true)
        XCTAssertEqual(pnRegister.id, 7)
        XCTAssertEqual(pnRegister.lastAccessed, 1_700_000_000)
        XCTAssertEqual(pnRegister.name, "Phone")
        XCTAssertEqual(postAlert.action, "ok")
    }
}

private func jsonObject(from value: some Encodable) throws -> Any {
    let data = try JSONEncoder().encode(AnyEncodable(value))
    return try JSONSerialization.jsonObject(with: data)
}

private struct AnyEncodable: Encodable {
    private let encodeImpl: (Encoder) throws -> Void

    init(_ wrapped: some Encodable) {
        encodeImpl = wrapped.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encodeImpl(encoder)
    }
}
