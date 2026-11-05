import Foundation
import RuuviLocalization
import RuuviOntology
import XCTest
@testable import station

@MainActor final class AccelerationDisplayTests: XCTestCase {
    func testSIAndGravityInputsProduceTheSameCardSettingsAndGraphReadings() throws {
        let fixture = MeasurementFixture()
        fixture.settings.accelerationAccuracy = .two
        for unit in [UnitAcceleration.gravity, .metersPerSecondSquared] {
            var record = fixture.record()
            record.acceleration = .init(
                x: .init(value: -1, unit: .gravity).converted(to: unit),
                y: .init(value: 0, unit: .gravity).converted(to: unit),
                z: .init(value: 1, unit: .gravity).converted(to: unit))
            _ = fixture.snapshot.updateFromRecord(
                record, sensor: fixture.sensor, measurementService: fixture.measurement, flags: fixture.flags)
            XCTAssertEqual(fixture.snapshot.displayData.accelerationX, -1)
            XCTAssertEqual(fixture.snapshot.displayData.accelerationY, 0)
            XCTAssertEqual(fixture.snapshot.displayData.accelerationZ, 1)
            let types: [MeasurementType] = [.accelerationX, .accelerationY, .accelerationZ]
            let rowIDs: [CardsSettingsMoreInfoRowID] = [.accX, .accY, .accZ]
            for (index, value) in [-1.0, 0, 1].enumerated() {
                let variant = MeasurementDisplayVariant(type: types[index])
                let result = try XCTUnwrap(MeasurementExtractorFactory.extractor(for: types[index])?.extract(
                    from: record, measurementService: fixture.measurement, flags: fixture.flags,
                    variant: variant, snapshot: fixture.snapshot))
                XCTAssertEqual(result.value, fixture.measurement.accelerationString(for: value))
                XCTAssertEqual(result.unit, RuuviLocalization.g)
                XCTAssertEqual(try XCTUnwrap(fixture.resolver().value(
                    for: record.measurement, variant: variant, sensorSettings: nil)), value, accuracy: 0.0001)
                let rows = CardsSettingsMoreInfoRowBuilder.buildMoreInfoRows(
                    from: fixture.snapshot, measurementService: fixture.measurement)
                let row = try XCTUnwrap(rows.first { $0.id == rowIDs[index].rawValue })
                XCTAssertTrue(row.value.hasPrefix(result.value))
                XCTAssertTrue(row.value.contains(RuuviLocalization.g))
            }
        }
    }
}
