import Foundation
import RuuviLocalization
import RuuviOntology
import XCTest
@testable import station

final class BeaverAdviceTests: XCTestCase {
    func testUnknownMissingAndStaleMeasurementsNeverProduceAdviceOrCrash() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        for co2: MeasurementQualityState? in [nil, .excellent(400)] {
            for pm: MeasurementQualityState? in [nil, .excellent(1)] {
                XCTAssertEqual(
                    BeaverAdviceHelper.getBeaverAdvice(
                        aqiQuality: .undefined(0), co2Quality: co2, pm25Quality: pm, lastUpdated: nil, now: now
                    ), RuuviLocalization.na)
            }
        }
        XCTAssertEqual(
            BeaverAdviceHelper.getBeaverAdvice(
                aqiQuality: .excellent(100), co2Quality: .excellent(400), pm25Quality: .excellent(1),
                lastUpdated: now.addingTimeInterval(-901), now: now
            ), RuuviLocalization.aqiAdviceOutdated)
        XCTAssertNotEqual(
            BeaverAdviceHelper.getBeaverAdvice(
                aqiQuality: .excellent(100), co2Quality: .excellent(400), pm25Quality: .excellent(1),
                lastUpdated: now.addingTimeInterval(-900), now: now
            ), RuuviLocalization.aqiAdviceOutdated)
    }

    func testAdviceDescribesEachCO2AndParticulateQualityCombination() {
        let states: [MeasurementQualityState] = [.excellent(100), .good(80), .fair(60), .poor(40), .veryPoor(20)]
        let suffixes: [[String?]] = [
            [
                nil, RuuviLocalization.aqiAdviceCo2ExcellentPmGood, RuuviLocalization.aqiAdviceCo2ExcellentPmFair,
                RuuviLocalization.aqiAdviceCo2ExcellentPmPoor, RuuviLocalization.aqiAdviceCo2ExcellentPmVerypoor,
            ],
            [
                RuuviLocalization.aqiAdviceCo2GoodPmExcellent, RuuviLocalization.aqiAdviceCo2GoodPmGood,
                RuuviLocalization.aqiAdviceCo2GoodPmFair, RuuviLocalization.aqiAdviceCo2GoodPmPoor,
                RuuviLocalization.aqiAdviceCo2GoodPmVerypoor,
            ],
            [
                RuuviLocalization.aqiAdviceCo2FairPmExcellent, RuuviLocalization.aqiAdviceCo2FairPmGood,
                RuuviLocalization.aqiAdviceCo2FairPmFair, RuuviLocalization.aqiAdviceCo2FairPmPoor,
                RuuviLocalization.aqiAdviceCo2FairPmVerypoor,
            ],
            [
                RuuviLocalization.aqiAdviceCo2PoorPmExcellent, RuuviLocalization.aqiAdviceCo2PoorPmGood,
                RuuviLocalization.aqiAdviceCo2PoorPmFair, RuuviLocalization.aqiAdviceCo2PoorPmPoor,
                RuuviLocalization.aqiAdviceCo2PoorPmVerypoor,
            ],
            [
                RuuviLocalization.aqiAdviceCo2VerypoorPmExcellent, RuuviLocalization.aqiAdviceCo2VerypoorPmGood,
                RuuviLocalization.aqiAdviceCo2VerypoorPmFair, RuuviLocalization.aqiAdviceCo2VerypoorPmPoor,
                RuuviLocalization.aqiAdviceCo2VerypoorPmVerypoor,
            ],
        ]
        for (row, co2) in states.enumerated() {
            for (column, pm) in states.enumerated() {
                let advice = BeaverAdviceHelper.getBeaverAdvice(
                    aqiQuality: states[max(row, column)], co2Quality: co2, pm25Quality: pm, lastUpdated: Date()
                )
                XCTAssertFalse(advice.isEmpty)
                XCTAssertNotEqual(advice, RuuviLocalization.na)
                if let suffix = suffixes[row][column] { XCTAssertTrue(advice.hasSuffix(suffix)) }
            }
            let unavailablePM = BeaverAdviceHelper.getBeaverAdvice(
                aqiQuality: co2, co2Quality: co2, pm25Quality: .undefined(0), lastUpdated: nil
            )
            XCTAssertFalse(unavailablePM.isEmpty)
        }
        XCTAssertFalse(
            BeaverAdviceHelper.getBeaverAdvice(
                aqiQuality: .good(80), co2Quality: .undefined(0), pm25Quality: .good(1), lastUpdated: nil
            ).isEmpty)
    }
}
