import Foundation
@testable import RuuviOntology
import XCTest

final class SensorModelTests: XCTestCase {
    func testLocalSensorEditsChangeOnlyTheRequestedField() {
        let sensor = modelSensor()
        let cases: [(String, String, RuuviTagSensor)] = [
            ("version", "6", sensor.with(version: 6)),
            ("firmware", "2.0.0", sensor.with(firmwareVersion: "2.0.0")),
            ("firmware", "-", sensor.withoutFirmwareVersion()),
            ("luid", "second", sensor.with(luid: "second".luid)),
            ("mac", "AA:BB:CC:11:22:33", sensor.with(macId: "AA:BB:CC:11:22:33".mac)),
            ("mac", "-", sensor.withoutMac()),
            ("name", "Renamed 🌡️", sensor.with(name: "Renamed 🌡️")),
            ("connectable", "false", sensor.with(isConnectable: false)),
            ("claimed", "false", sensor.with(isClaimed: false)),
            ("ownerFlag", "false", sensor.with(isOwner: false)),
            ("owner", "new@example.com", sensor.with(owner: "new@example.com")),
            ("plan", "pro", sensor.with(ownersPlan: "pro")),
            ("cloud", "false", sensor.with(isCloudSensor: false)),
            ("canShare", "false", sensor.with(canShare: false)),
            ("shared", "new@example.com", sensor.with(sharedTo: ["new@example.com"])),
            ("pending", "invite@example.com", sensor.with(sharedToPending: ["invite@example.com"])),
            ("history", "30", sensor.with(maxHistoryDays: 30)),
            ("updated", "-", sensor.with(lastUpdated: nil)),
        ]
        let original = sensorValues(sensor)
        for (key, value, edited) in cases {
            var expected = original
            expected[key] = value
            XCTAssertEqual(sensorValues(edited), expected, key)
            XCTAssertEqual(sensorValues(sensor), original, "Edits must not mutate the original sensor")
        }
        XCTAssertEqual(sensorValues(sensor.struct), original)
        XCTAssertEqual(sensorValues(sensor.any), original)
        XCTAssertEqual(sensor.any.orderElement, sensor.id)
        XCTAssertEqual(sensor.id, sensor.macId?.value)
        XCTAssertEqual(sensor.withoutMac().id, "local")
        XCTAssertEqual(sensor.with(macId: "".mac).id, "local")
        var ownerless = original
        ownerless["owner"] = "-"
        ownerless["plan"] = "-"
        XCTAssertEqual(sensorValues(sensor.withoutOwner()), ownerless)
    }

    func testOwnershipAndUnclaimPreserveLocalSensorAndSharingInformation() {
        let sensor = modelSensor()
        XCTAssertEqual(sensor.ownership, .claimedByMe)
        XCTAssertEqual(sensor.with(isClaimed: false).with(isOwner: false).ownership, .sharedWithMe)
        XCTAssertEqual(
            sensor.with(isClaimed: false).with(isOwner: false).with(isCloudSensor: false).ownership,
            .locallyAddedButNotMine)
        XCTAssertEqual(sensor.with(isClaimed: false).with(isCloudSensor: false).ownership, .locallyAddedAndNotClaimed)
        let unclaimed = sensor.unclaimed()
        var expected = sensorValues(sensor)
        for (key, value) in [
            "claimed": "false", "ownerFlag": "true", "owner": "-", "plan": "-", "cloud": "false",
        ] { expected[key] = value }
        XCTAssertEqual(sensorValues(unclaimed), expected)
        XCTAssertFalse(unclaimed.isCloud)
        var local = sensor
        local.isCloudSensor = nil
        XCTAssertFalse(local.isCloud)
        local.sharedTo = ["", "a@example.com", ""]
        local.sharedToPending = ["", "b@example.com"]
        XCTAssertEqual(local.any.sharedTo, ["a@example.com"])
        XCTAssertEqual(local.any.sharedToPending, ["b@example.com"])
    }

    func testCloudMergePreservesBluetoothMetadataAndUsesCloudOwnership() {
        let local = modelSensor()
        var cloud = modelCloud()
        cloud.name = ""
        cloud.isCloudSensor = nil
        let merged = local.with(cloudSensor: cloud)
        XCTAssertEqual(merged.name, cloud.id)
        XCTAssertEqual(merged.version, local.version)
        XCTAssertEqual(merged.luid?.value, local.luid?.value)
        XCTAssertEqual(merged.macId?.value, local.macId?.value)
        XCTAssertEqual(merged.firmwareVersion, local.firmwareVersion)
        XCTAssertEqual(merged.serviceUUID, local.serviceUUID)
        XCTAssertEqual(merged.isConnectable, local.isConnectable)
        XCTAssertFalse(merged.isClaimed)
        XCTAssertFalse(merged.isOwner)
        XCTAssertTrue(merged.isCloud)
        XCTAssertEqual(merged.owner, cloud.owner)
        XCTAssertEqual(merged.ownersPlan, cloud.ownersPlan)
        XCTAssertEqual(merged.sharedTo, cloud.sharedTo)
        XCTAssertEqual(merged.sharedToPending, cloud.sharedToPending)
        XCTAssertEqual(merged.maxHistoryDays, cloud.maxHistoryDays)
        XCTAssertEqual(merged.lastUpdated, cloud.lastUpdated)
        cloud.name = "Cloud name"
        cloud.isOwner = true
        XCTAssertEqual(local.with(cloudSensor: cloud).name, "Cloud name")
        XCTAssertTrue(local.with(cloudSensor: cloud).isClaimed)
        let owned = cloud.with(email: "OWNER@EXAMPLE.COM")
        XCTAssertTrue(owned.isOwner)
        XCTAssertEqual(owned.owner, "owner@example.com")
        XCTAssertFalse(cloud.with(email: "somebody@example.com").isOwner)
    }

    func testHashableSensorIdentityIsTransitiveAndSurvivesSetAndDictionaryLookup() {
        let first = modelSensor().any
        let renamed = modelSensor().with(name: "Renamed").any
        let otherMAC = modelSensor().with(macId: "AA:BB:CC:11:22:33".mac).any
        let otherLocal = modelSensor().with(luid: "other-local".luid).any
        XCTAssertEqual(first, renamed)
        XCTAssertEqual(first, otherLocal)
        XCTAssertEqual(first.hashValue, renamed.hashValue)
        XCTAssertEqual(first.hashValue, otherLocal.hashValue)
        // A reused local UUID must not merge two distinct hardware addresses.
        XCTAssertNotEqual(first, otherMAC)
        XCTAssertNotEqual(otherMAC, otherLocal)
        XCTAssertEqual(Set([first, renamed, otherMAC, otherLocal]).count, 2)
        XCTAssertEqual([first: "stored"][otherLocal], "stored")
        XCTAssertEqual([first: "stored"][renamed], "stored")
        XCTAssertNil([first: "stored"][otherMAC])
    }
}

func modelSensor() -> RuuviTagSensorStruct {
    .init(
        version: 225, firmwareVersion: "1.0.0", luid: "local".luid, macId: "AA:BB:CC:DD:EE:FF".mac,
        serviceUUID: "service", isConnectable: true, name: "Indoor", isClaimed: true, isOwner: true,
        owner: "owner@example.com", ownersPlan: "basic", isCloudSensor: true, canShare: true,
        sharedTo: ["friend@example.com"], sharedToPending: ["pending@example.com"], maxHistoryDays: 10,
        lastUpdated: Date(timeIntervalSince1970: 100))
}

func modelCloud() -> CloudSensorStruct {
    .init(
        id: "AA:BB:CC:DD:EE:FF", serviceUUID: "cloud-service", name: "Cloud", isClaimed: false, isOwner: false,
        owner: "Owner@Example.COM", ownersPlan: "pro", picture: URL(string: "https://example.com/sensor.png"),
        offsetTemperature: 1, offsetHumidity: 0.02, offsetPressure: 3, isCloudSensor: true, canShare: false,
        sharedTo: ["a@example.com"], sharedToPending: ["b@example.com"], maxHistoryDays: 30,
        lastUpdated: Date(timeIntervalSince1970: 200))
}

func sensorValues(_ sensor: RuuviTagSensor) -> [String: String] {
    [
        "version": String(sensor.version), "firmware": sensor.firmwareVersion ?? "-",
        "luid": sensor.luid?.value ?? "-", "mac": sensor.macId?.value ?? "-", "service": sensor.serviceUUID ?? "-",
        "connectable": String(sensor.isConnectable), "name": sensor.name, "claimed": String(sensor.isClaimed),
        "ownerFlag": String(sensor.isOwner), "owner": sensor.owner ?? "-", "plan": sensor.ownersPlan ?? "-",
        "cloud": sensor.isCloudSensor.map(String.init) ?? "-", "canShare": String(sensor.canShare),
        "shared": sensor.sharedTo.joined(separator: ","), "pending": sensor.sharedToPending.joined(separator: ","),
        "history": sensor.maxHistoryDays.map(String.init) ?? "-",
        "updated": sensor.lastUpdated.map { String($0.timeIntervalSince1970) } ?? "-",
    ]
}
