import Foundation
import Intents
import RuuviOntology
import XCTest
@testable import RuuviWidgets

@MainActor final class WidgetConfigurationTests: XCTestCase {
    func testLegacyIntentRoundTripPreservesSensorAndMeasurementIdentifiers() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        let intent = fixture.intent()
        intent.ruuviWidgetTag?.deviceType = .ruuviAir
        intent.sensorSelection = RuuviWidgetTagSensor(identifier: "CO2_PPM", display: "CO₂")
        let config = SingleSensorWidgetConfiguration(intent: intent)
        XCTAssertEqual(config.sensorId, "AA:BB:CC:DD:EE:01")
        XCTAssertEqual(config.deviceType, .ruuviAir)
        XCTAssertEqual(config.sensorSelectionIdentifier, "CO2_PPM")
        XCTAssertEqual(config.sensor, .temperature)
        let data = try NSKeyedArchiver.archivedData(withRootObject: intent, requiringSecureCoding: false)
        let decoder = try NSKeyedUnarchiver(forReadingFrom: data)
        decoder.requiresSecureCoding = false
        defer { decoder.finishDecoding() }
        let restored = try XCTUnwrap(
            decoder.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? RuuviTagSelectionIntent)
        XCTAssertEqual(SingleSensorWidgetConfiguration(intent: restored), config)
    }

    func testNoneAndEmptySelectionsNeverBecomeSensorIdentifiers() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        for id: String? in [nil, "", WidgetConfigurationSelection.noneIdentifier] {
            XCTAssertNil(SingleSensorWidgetConfiguration(intent: fixture.intent(id: id)).sensorId)
        }
        let none = WidgetConfigurationSelection.noneTag()
        XCTAssertEqual(none.identifier, WidgetConfigurationSelection.noneIdentifier)
        XCTAssertFalse(none.displayString.isEmpty)
        XCTAssertEqual(none.deviceType, .unknown)
    }

    func testMultiSensorConfigurationKeepsSelectionOrderAndRemovesDuplicates() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        let intent = fixture.multiIntent(["B", "A", "B", WidgetConfigurationSelection.noneIdentifier, "C", "D"])
        XCTAssertEqual(fixture.multiProvider.selectedSensors(from: intent), ["B", "A", "C", "D"])
        XCTAssertEqual(fixture.multiProvider.selectedSensors(from: fixture.multiIntent([])), [])
        XCTAssertEqual(
            fixture.multiProvider.selectedSensors(from: fixture.multiIntent(["1", "2", "3", "4", "5", "6"])),
            ["1", "2", "3", "4", "5", "6"])
    }
}
