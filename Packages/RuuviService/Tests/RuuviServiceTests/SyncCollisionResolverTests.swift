@testable import RuuviService
import RuuviOntology
import XCTest

final class SyncCollisionResolverTests: XCTestCase {
    func testPreferCloudWhenBothTimestampsAreMissingIsOptIn() {
        XCTAssertEqual(
            SyncCollisionResolver.resolve(
                localTimestamp: nil,
                cloudTimestamp: nil
            ),
            .noAction
        )

        XCTAssertEqual(
            SyncCollisionResolver.resolve(
                localTimestamp: nil,
                cloudTimestamp: nil,
                preferCloudWhenBothTimestampsMissing: true
            ),
            .updateLocal
        )
    }

    func testNoActionDoesNotForceRefreshForNameOrTimestampDrift() {
        let cloudTimestamp = Date(timeIntervalSince1970: 1_000)
        let localTimestamp = Date(timeIntervalSince1970: 1_000.9)

        XCTAssertEqual(
            SyncCollisionResolver.resolve(
                localTimestamp: localTimestamp,
                cloudTimestamp: cloudTimestamp,
                preferCloudWhenBothTimestampsMissing: true
            ),
            .noAction
        )

        let localSensor = makeLocalSensor(
            name: "Local name",
            sharedTo: ["shared@example.com"],
            lastUpdated: localTimestamp
        )
        let cloudSensor = makeCloudSensor(
            name: "Cloud name",
            sharedTo: ["shared@example.com"],
            lastUpdated: cloudTimestamp
        )

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
                localTimestamp: localTimestamp,
                cloudTimestamp: cloudTimestamp,
                preferCloudWhenBothTimestampsMissing: true
            ),
            .noAction
        )

        let localSensor = makeLocalSensor(
            canShare: false,
            sharedTo: [],
            lastUpdated: localTimestamp
        )
        let cloudSensor = makeCloudSensor(
            ownersPlan: "pro",
            canShare: true,
            sharedTo: ["shared@example.com"],
            sharedToPending: ["pending@example.com"],
            maxHistoryDays: 365,
            lastUpdated: cloudTimestamp
        )

        XCTAssertTrue(
            SyncCollisionResolver.shouldRefreshCloudAuthoritativeFields(
                localSensor: localSensor,
                cloudSensor: cloudSensor
            )
        )
    }

    private func makeLocalSensor(
        name: String = "Sensor",
        ownersPlan: String = "free",
        canShare: Bool = true,
        sharedTo: [String] = [],
        sharedToPending: [String] = [],
        maxHistoryDays: Int = 30,
        lastUpdated: Date?
    ) -> AnyRuuviTagSensor {
        RuuviTagSensorStruct(
            version: 5,
            firmwareVersion: nil,
            luid: nil,
            macId: "AA:BB:CC:DD:EE:FF".mac,
            serviceUUID: nil,
            isConnectable: true,
            name: name,
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: ownersPlan,
            isCloudSensor: true,
            canShare: canShare,
            sharedTo: sharedTo,
            sharedToPending: sharedToPending,
            maxHistoryDays: maxHistoryDays,
            lastUpdated: lastUpdated
        ).any
    }

    private func makeCloudSensor(
        name: String = "Sensor",
        ownersPlan: String = "free",
        canShare: Bool = true,
        sharedTo: [String] = [],
        sharedToPending: [String] = [],
        maxHistoryDays: Int = 30,
        lastUpdated: Date?
    ) -> AnyCloudSensor {
        CloudSensorStruct(
            id: "AA:BB:CC:DD:EE:FF",
            serviceUUID: nil,
            name: name,
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: ownersPlan,
            picture: nil,
            offsetTemperature: nil,
            offsetHumidity: nil,
            offsetPressure: nil,
            isCloudSensor: true,
            canShare: canShare,
            sharedTo: sharedTo,
            sharedToPending: sharedToPending,
            maxHistoryDays: maxHistoryDays,
            lastUpdated: lastUpdated
        ).any
    }
}
