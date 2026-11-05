import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class CardSettingsViewTests: XCTestCase {
    func testSettingsActionsForwardExactlyOnceToTheirPresenter() throws {
        let fixture = try CardSettingsViewFixture()
        defer { fixture.close() }
        XCTAssertEqual(fixture.output.loads, 1)
        fixture.actions.didTapBackgroundChange.send()
        fixture.actions.didTapOwnerRow.send()
        fixture.actions.didTapShareRow.send()
        fixture.actions.didTapVisibleMeasurementsRow.send()
        fixture.actions.didTapLedBrightnessRow.send()
        fixture.actions.didTapNotesRow.send()
        fixture.actions.didTapMoreInfoMacAddress.send()
        fixture.actions.didTapMoreInfoTxPower.send()
        fixture.actions.didTapMoreInfoMeasurementSequence.send()
        fixture.actions.didTapTemperatureOffset.send()
        fixture.actions.didTapHumidityOffset.send()
        fixture.actions.didTapPressureOffset.send()
        fixture.actions.didTapFirmwareUpdate.send()
        fixture.actions.didTapRemove.send()
        fixture.actions.didTapNoValuesIndicator.send()
        fixture.actions.didTapAlertsShortcut.send()
        XCTAssertEqual(
            fixture.output.events,
            [
                "background", "owner", "share", "visibility", "led", "notes", "mac", "power",
                "sequence", "temperature-offset", "humidity-offset", "pressure-offset", "firmware", "remove",
                "no-values", "alerts",
            ])
        fixture.actions.didToggleKeepConnection.send(true)
        fixture.actions.didToggleKeepConnection.send(false)
        XCTAssertEqual(fixture.output.keep, [true, false])
        fixture.actions.didToggleAlert.send((fixture.temperature, true))
        XCTAssertEqual(fixture.output.toggles.first?.0.rawValue, fixture.temperature.rawValue)
        XCTAssertEqual(fixture.output.toggles.first?.1, true)
    }

    func testOnlyFinalChangedAndOrderedSliderBoundsAreSaved() throws {
        let fixture = try CardSettingsViewFixture()
        defer { fixture.close() }
        let type = fixture.temperature
        fixture.actions.didChangeAlertRange.send(.init(alertType: type, lowerBound: 5, upperBound: 25, isFinal: false))
        fixture.actions.didChangeAlertRange.send(.init(alertType: type, lowerBound: 30, upperBound: 0, isFinal: true))
        fixture.actions.didChangeAlertRange.send(.init(alertType: type, lowerBound: 0, upperBound: 30, isFinal: true))
        XCTAssertTrue(fixture.output.lower.isEmpty)
        XCTAssertTrue(fixture.output.upper.isEmpty)
        fixture.actions.didChangeAlertRange.send(.init(alertType: type, lowerBound: 5, upperBound: 30, isFinal: true))
        fixture.actions.didChangeAlertRange.send(.init(alertType: type, lowerBound: 0, upperBound: 25, isFinal: true))
        XCTAssertEqual(fixture.output.lower.map(\.1), [5])
        XCTAssertEqual(fixture.output.upper.map(\.1), [25])
        fixture.actions.didChangeAlertRange.send(.init(alertType: type, lowerBound: 10, upperBound: 20, isFinal: true))
        XCTAssertEqual(fixture.output.lower.map(\.1), [5, 10])
        XCTAssertEqual(fixture.output.upper.map(\.1), [25, 20])
    }

    func testRenameAndDescriptionEditorsUseTheCorrectValuesAndLimits() async throws {
        let fixture = try CardSettingsViewFixture()
        defer { fixture.close() }
        fixture.actions.didTapSnapshotName.send()
        let rename = try await fixture.alert()
        XCTAssertEqual(rename.title, RuuviLocalization.TagSettings.TagNameTitleLabel.text)
        XCTAssertEqual(rename.message, RuuviLocalization.TagSettings.TagNameTitleLabel.Rename.text)
        let name = try XCTUnwrap(rename.textFields?.first)
        XCTAssertEqual(name.text, fixture.builder.measurements.snapshot.displayData.name)
        name.text = String(repeating: "a", count: 31)
        XCTAssertTrue(
            fixture.view.textField(
                name, shouldChangeCharactersIn: NSRange(location: 31, length: 0), replacementString: "b"))
        XCTAssertFalse(
            fixture.view.textField(
                name, shouldChangeCharactersIn: NSRange(location: 31, length: 0), replacementString: "bc"))
        await fixture.dismissAlert()
        fixture.actions.didRequestAlertDescriptionEdit.send(fixture.temperature)
        let description = try await fixture.alert()
        XCTAssertEqual(description.title, RuuviLocalization.TagSettings.Alert.CustomDescription.title)
        let field = try XCTUnwrap(description.textFields?.first)
        XCTAssertEqual(field.text, "Custom " + fixture.temperature.rawValue)
        field.text = String(repeating: "x", count: 32)
        XCTAssertFalse(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 32, length: 0), replacementString: "y"))
        XCTAssertTrue(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 31, length: 1), replacementString: ""))
    }

    func testManualRangeEditorShowsLimitsAndValidatesDecimalInput() async throws {
        let fixture = try CardSettingsViewFixture()
        defer { fixture.close() }
        fixture.actions.didRequestAlertLimitEdit.send(fixture.temperature)
        let alert = try await fixture.alert()
        let lower = try XCTUnwrap(alert.textFields?.first)
        let upper = try XCTUnwrap(alert.textFields?.last)
        XCTAssertEqual(lower.text, "0")
        XCTAssertEqual(upper.text, "30")
        XCTAssertFalse((lower.placeholder ?? "").isEmpty)
        XCTAssertFalse((upper.placeholder ?? "").isEmpty)
        let separator = Locale.current.decimalSeparator ?? "."
        lower.text = "12" + separator + "34"
        XCTAssertFalse(
            fixture.view.textField(
                lower, shouldChangeCharactersIn: NSRange(location: 5, length: 0), replacementString: "5"))
        XCTAssertFalse(
            fixture.view.textField(
                lower, shouldChangeCharactersIn: NSRange(location: 2, length: 0), replacementString: separator))
        XCTAssertTrue(
            fixture.view.textField(
                lower, shouldChangeCharactersIn: NSRange(location: 4, length: 1), replacementString: ""))
        upper.text = ""
        XCTAssertTrue(
            fixture.view.textField(
                upper, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "-"))
        XCTAssertTrue(
            fixture.view.textField(
                upper, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "2"))
        XCTAssertFalse(
            fixture.view.textField(
                upper, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "a"))
    }

    func testCloudDelayEditorEnforcesMinimumMinutesAndDigits() async throws {
        let fixture = try CardSettingsViewFixture()
        defer { fixture.close() }
        fixture.actions.didTapCloudConnectionDelay.send()
        let alert = try await fixture.alert()
        let field = try XCTUnwrap(alert.textFields?.first)
        let save = try XCTUnwrap(alert.actions.first)
        XCTAssertEqual(field.text, "15")
        XCTAssertTrue(save.isEnabled)
        for input in ["", "bad", "-1", "1"] {
            field.text = input
            field.sendActions(for: .editingChanged)
            XCTAssertFalse(save.isEnabled, input)
        }
        field.text = String(RuuviAlertConstants.CloudConnection.minUnseenDuration)
        field.sendActions(for: .editingChanged)
        XCTAssertTrue(save.isEnabled)
        field.text = "9"
        XCTAssertTrue(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 1, length: 0), replacementString: "9"))
        XCTAssertFalse(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 1, length: 0), replacementString: "99"))
        XCTAssertFalse(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 1, length: 0), replacementString: "x"))
    }
}
