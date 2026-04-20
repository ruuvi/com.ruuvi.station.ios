@testable import RuuviOntology
import XCTest

final class RuuviOntologyTests: XCTestCase {
    func testAnyMacIdentifierEqualityUsesNormalizedLastThreeBytes() {
        XCTAssertEqual("AA:BB:CC:11:22:33".mac.any, "11-22-33".mac.any)
        XCTAssertNotEqual("AA:BB:CC:11:22:33".mac.any, "44:55:66".mac.any)
        XCTAssertTrue("AA:BB:CC:11:22:33".isLast3BytesEqual(to: "11-22-33"))
    }

    func testFirmwareDisplayValueDropsTrailingPlusZeroSuffix() {
        XCTAssertEqual("3.31.0+0".ruuviFirmwareDisplayValue, "3.31.0")
        XCTAssertEqual("3.31.0+1".ruuviFirmwareDisplayValue, "3.31.0+1")
        XCTAssertNil(Optional<String>.none.ruuviFirmwareDisplayValue)
        XCTAssertEqual(Optional("3.31.0+0").ruuviFirmwareDisplayValue, "3.31.0")
    }

    func testMeasurementDisplayProfileFiltersByVisibilityAndContextWhilePreservingOrder() {
        let profile = MeasurementDisplayProfile(entries: [
            MeasurementDisplayEntry(.temperature, visible: true, contexts: [.indicator, .graph]),
            MeasurementDisplayEntry(.humidity, visible: false, contexts: .all),
            MeasurementDisplayEntry(.pressure, visible: true, contexts: .graph),
            MeasurementDisplayEntry(.rssi, visible: true, contexts: .indicator),
        ])

        XCTAssertEqual(profile.orderedVisibleTypes, [.temperature, .rssi])
        XCTAssertEqual(profile.orderedVisibleTypes(for: .graph), [.temperature, .pressure])
        XCTAssertEqual(profile.entriesSupporting(.graph).map(\.type), [.temperature, .humidity, .pressure])
    }

    func testIdentifierHelpersCoverConcreteOptionalAndHashableCases() {
        let concreteMac = MACIdentifierStruct(value: "AA:BB:CC:11:22:33")
        let optionalLuid: String? = "luid-1"
        let optionalMac: String? = "11:22:33"
        let missingValue: String? = nil

        XCTAssertEqual(concreteMac.mac, "AA:BB:CC:11:22:33")
        XCTAssertEqual(concreteMac.any.mac, "AA:BB:CC:11:22:33")
        XCTAssertEqual(optionalLuid.luid?.value, "luid-1")
        XCTAssertEqual(optionalMac.mac?.value, "11:22:33")
        XCTAssertNil(missingValue.luid)
        XCTAssertNil(missingValue.mac)

        let normalizedMacs: Set<AnyMACIdentifier> = [
            "AA:BB:CC:11:22:33".mac.any,
            "11-22-33".mac.any
        ]
        XCTAssertEqual(normalizedMacs.count, 1)
        XCTAssertEqual(Set(["luid-1".luid.any, "luid-1".luid.any]).count, 1)
    }

    func testRuuviTagSensorHelpersCoverOwnershipAndRemainingMutators() {
        let updatedAt = Date(timeIntervalSince1970: 321)
        let base = RuuviTagSensorStruct(
            version: 5,
            firmwareVersion: "3.31.0+0",
            luid: "luid-1".luid,
            macId: "AA:BB:CC:11:22:33".mac,
            serviceUUID: "service",
            isConnectable: true,
            name: "Kitchen",
            isClaimed: false,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: "pro",
            isCloudSensor: nil,
            canShare: true,
            sharedTo: ["friend@example.com", ""],
            maxHistoryDays: 30,
            lastUpdated: updatedAt
        )

        XCTAssertEqual(base.ownership, .locallyAddedAndNotClaimed)
        XCTAssertEqual(base.displayFirmwareVersion, "3.31.0")
        XCTAssertEqual(base.struct.ownersPlan, "pro")
        XCTAssertEqual(base.struct.lastUpdated, updatedAt)
        XCTAssertEqual(base.any.orderElement, base.id)

        XCTAssertEqual(base.with(isClaimed: true).ownership, .claimedByMe)
        XCTAssertEqual(base.with(isOwner: false).with(isCloudSensor: true).ownership, .sharedWithMe)
        XCTAssertEqual(
            base.with(isOwner: false).with(isCloudSensor: false).ownership,
            .locallyAddedButNotMine
        )

        let retagged = base
            .with(firmwareVersion: "4.0.0")
            .with(ownersPlan: "business")
            .with(isConnectable: false)
        XCTAssertEqual(retagged.firmwareVersion, "4.0.0")
        XCTAssertEqual(retagged.ownersPlan, "business")
        XCTAssertFalse(retagged.isConnectable)

        let withoutMac = base.withoutMac()
        XCTAssertNil(withoutMac.macId)
        XCTAssertEqual(withoutMac.id, "luid-1")

        let unidentified: RuuviTagSensor = RuuviTagSensorStruct(
            version: 5,
            firmwareVersion: nil,
            luid: nil,
            macId: nil,
            serviceUUID: nil,
            isConnectable: false,
            name: "Unidentified",
            isClaimed: false,
            isOwner: false,
            owner: nil,
            ownersPlan: nil,
            isCloudSensor: nil,
            canShare: false,
            sharedTo: [],
            maxHistoryDays: nil
        )
        XCTAssertEqual(unidentified.id, "")

        let cloudSensor = CloudSensorStruct(
            id: "11:22:33:44:55:66",
            serviceUUID: "cloud-service",
            name: "",
            isClaimed: false,
            isOwner: false,
            owner: nil,
            ownersPlan: "starter",
            picture: nil,
            offsetTemperature: nil,
            offsetHumidity: nil,
            offsetPressure: nil,
            isCloudSensor: nil,
            canShare: false,
            sharedTo: [],
            maxHistoryDays: 7,
            lastUpdated: updatedAt
        )
        let merged = base.with(cloudSensor: cloudSensor)

        XCTAssertEqual(merged.name, "11:22:33:44:55:66")
        XCTAssertEqual(merged.ownersPlan, "starter")
        XCTAssertEqual(merged.isCloudSensor, true)
    }
}
