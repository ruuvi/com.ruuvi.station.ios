@testable import station
@testable import RuuviLocal
import UIKit
import XCTest

final class DefaultsIntegerEditorTests: XCTestCase {
    private let configuration = DefaultsIntegerEditorConfiguration(
        range: RuuviMarketingConsentPromptInterval.allowedMinutes,
        message: "Interval",
        presets: [],
        formatValue: DefaultsIntegerEditorConfiguration.formatMinutes
    )

    func testIntervalPolicyHasOneDefaultAndClampsCorruptValues() {
        XCTAssertEqual(RuuviMarketingConsentPromptInterval.defaultMinutes, 259200)
        XCTAssertEqual(RuuviMarketingConsentPromptInterval.normalized(Int.min), 1)
        XCTAssertEqual(RuuviMarketingConsentPromptInterval.normalized(0), 1)
        XCTAssertEqual(RuuviMarketingConsentPromptInterval.normalized(7), 7)
        XCTAssertEqual(RuuviMarketingConsentPromptInterval.normalized(Int.max), Int(Int32.max))
    }

    func testValidationAcceptsCustomMinutesAndSurroundingWhitespace() {
        for value in ["1", "7", "259200", " 15\n", String(Int32.max)] {
            XCTAssertNotNil(configuration.validatedValue(from: value), value)
        }
        for value in ["", "0", "-1", "1.5", "abc", "2147483648", String(Int.max)] {
            XCTAssertNil(configuration.validatedValue(from: value), value)
        }
        XCTAssertNil(configuration.validatedValue(from: nil))
    }

    func testPersistedFlagUsesTheSameDefaultAndBoundsAsTheEditor() {
        let key = "RuuviFeatureFlags.marketingConsentPromptIntervalMinutes"
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: key)
        defer {
            if let original { defaults.set(original, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        defaults.removeObject(forKey: key)
        let flags = RuuviLocalFlagsUserDefaults()
        XCTAssertEqual(flags.marketingConsentPromptIntervalMinutes, 259200)
        defaults.set(Int.max, forKey: key)
        XCTAssertEqual(flags.marketingConsentPromptIntervalMinutes, configuration.range.upperBound)
        flags.marketingConsentPromptIntervalMinutes = 0
        XCTAssertEqual(defaults.integer(forKey: key), 1)
        flags.marketingConsentPromptIntervalMinutes = 7
        XCTAssertEqual(RuuviLocalFlagsUserDefaults().marketingConsentPromptIntervalMinutes, 7)
    }

    @MainActor func testReusedCellRestoresEachStepperRangeAndEditingAffordance() {
        let cell = DefaultsStepperTableViewCell(style: .default, reuseIdentifier: nil)
        cell.titleLabel = UILabel()
        cell.stepper = UIStepper()
        let model = DefaultsViewModel()
        model.title = "Interval"
        model.integer.value = RuuviMarketingConsentPromptInterval.defaultMinutes
        model.integerEditor = configuration
        cell.configure(with: model)
        XCTAssertEqual(cell.stepper.value, 259200)
        XCTAssertEqual(cell.stepper.minimumValue, 1)
        XCTAssertEqual(cell.stepper.stepValue, 1)
        XCTAssertEqual(cell.accessoryType, .disclosureIndicator)

        model.integerEditor = nil
        model.unit = .minutes
        model.integer.value = 15
        cell.configure(with: model)
        XCTAssertEqual(cell.stepper.maximumValue, 3600)
        XCTAssertEqual(cell.stepper.stepValue, 5)
        XCTAssertEqual(cell.accessoryType, .none)
        XCTAssertFalse(cell.titleLabel.text?.contains("Tap to edit") ?? true)

        model.item.value = .graphDownsampleMaximumPoints
        model.unit = .decimal
        model.integer.value = 3000
        cell.configure(with: model)
        XCTAssertEqual(cell.stepper.minimumValue, 1000)
        XCTAssertEqual(cell.stepper.maximumValue, 5000)
        XCTAssertEqual(cell.stepper.stepValue, 100)

        model.item.value = .imageCompressionQuality
        model.integer.value = 50
        cell.configure(with: model)
        XCTAssertEqual(cell.stepper.minimumValue, 10)
        XCTAssertEqual(cell.stepper.maximumValue, 100)
        XCTAssertEqual(cell.stepper.stepValue, 10)
        XCTAssertEqual(cell.titleLabel.text, "Interval (50%)")
    }
}
