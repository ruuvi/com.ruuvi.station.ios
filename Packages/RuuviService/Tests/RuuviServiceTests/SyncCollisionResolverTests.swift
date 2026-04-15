@testable import RuuviService
import RuuviOntology
import XCTest

final class SyncCollisionResolverTests: XCTestCase {
    func testNoActionDoesNotForceRefreshForNameOrTimestampDrift() {
        let cloudTimestamp = Date(timeIntervalSince1970: 1_000)
        let localTimestamp = Date(timeIntervalSince1970: 1_000.9)

        XCTAssertEqual(
            SyncCollisionResolver.resolve(
                isOwner: true,
                localTimestamp: localTimestamp,
                cloudTimestamp: cloudTimestamp
            ),
            .noAction
        )

        let localSensor = RuuviTagSensorStruct(
            version: 5,
            firmwareVersion: nil,
            luid: nil,
            macId: "AA:BB:CC:DD:EE:FF".mac,
            serviceUUID: nil,
            isConnectable: true,
            name: "Local name",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: "free",
            isCloudSensor: true,
            canShare: true,
            sharedTo: ["shared@example.com"],
            sharedToPending: [],
            maxHistoryDays: 30,
            lastUpdated: localTimestamp
        ).any
        let cloudSensor = CloudSensorStruct(
            id: "AA:BB:CC:DD:EE:FF",
            serviceUUID: nil,
            name: "Cloud name",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: "free",
            picture: nil,
            offsetTemperature: nil,
            offsetHumidity: nil,
            offsetPressure: nil,
            isCloudSensor: true,
            canShare: true,
            sharedTo: ["shared@example.com"],
            sharedToPending: [],
            maxHistoryDays: 30,
            lastUpdated: cloudTimestamp
        ).any

        XCTAssertFalse(
            SyncCollisionResolver.shouldRefreshCloudAuthoritativeFields(
                localSensor: localSensor,
                cloudSensor: cloudSensor
            )
        )
    }

    func testNoActionStillRefreshesCloudAuthoritativeFields() {
        let cloudTimestamp = Date(timeIntervalSince1970: 1_000)
        let localTimestamp = Date(timeIntervalSince1970: 1_000.4)

        XCTAssertEqual(
            SyncCollisionResolver.resolve(
                isOwner: true,
                localTimestamp: localTimestamp,
                cloudTimestamp: cloudTimestamp
            ),
            .noAction
        )

        let localSensor = RuuviTagSensorStruct(
            version: 5,
            firmwareVersion: nil,
            luid: nil,
            macId: "AA:BB:CC:DD:EE:FF".mac,
            serviceUUID: nil,
            isConnectable: true,
            name: "Sensor",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: "free",
            isCloudSensor: true,
            canShare: false,
            sharedTo: [],
            sharedToPending: [],
            maxHistoryDays: 30,
            lastUpdated: localTimestamp
        ).any
        let cloudSensor = CloudSensorStruct(
            id: "AA:BB:CC:DD:EE:FF",
            serviceUUID: nil,
            name: "Sensor",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: "pro",
            picture: nil,
            offsetTemperature: nil,
            offsetHumidity: nil,
            offsetPressure: nil,
            isCloudSensor: true,
            canShare: true,
            sharedTo: ["shared@example.com"],
            sharedToPending: ["pending@example.com"],
            maxHistoryDays: 365,
            lastUpdated: cloudTimestamp
        ).any

        XCTAssertTrue(
            SyncCollisionResolver.shouldRefreshCloudAuthoritativeFields(
                localSensor: localSensor,
                cloudSensor: cloudSensor
            )
        )
    }
}
