import Foundation
import RuuviOntology

enum CardsSettingsAlertLimitDescription: Equatable {
    case staticText(String)
    case sliderLocalized
}

struct CardsSettingsAlertRangeChange {
    let alertType: AlertType
    let lowerBound: Double
    let upperBound: Double
    /// `true` when the user lifted their finger and editing finished.
    let isFinal: Bool
}

struct CardsSettingsAlertLatestMeasurement: Equatable {
    let value: String
    let suffix: String?
    let separator: String

    init(
        value: String,
        suffix: String? = nil,
        separator: String = String.nbsp
    ) {
        self.value = value
        self.suffix = suffix
        self.separator = suffix == nil ? "" : separator
    }

    init?(text: String?) {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let separatorIndex = trimmed.lastIndex(where: { character in
            Self.isWhitespace(character)
        }) else {
            value = trimmed
            suffix = nil
            separator = ""
            return
        }

        let valuePart = String(trimmed[..<separatorIndex])
        let suffixStartIndex = trimmed.index(after: separatorIndex)
        let suffixPart = String(trimmed[suffixStartIndex...])

        value = valuePart
        suffix = suffixPart.isEmpty ? nil : suffixPart
        separator = suffixPart.isEmpty ? "" : String(trimmed[separatorIndex])
    }

    var text: String {
        guard let suffix else { return value }
        return value + separator + suffix
    }

    private static func isWhitespace(_ character: Character) -> Bool {
        String(character).unicodeScalars.allSatisfy {
            CharacterSet.whitespacesAndNewlines.contains($0) || $0.value == 0x00A0
        }
    }
}

struct CardsSettingsAlertUIConfiguration: Equatable {
    init(
        isEnabled: Bool,
        noticeText: String? = nil,
        customDescriptionText: String? = nil,
        limitDescription: CardsSettingsAlertLimitDescription? = nil,
        showsLimitEditIcon: Bool,
        sliderConfiguration: CardsSettingsAlertSliderConfiguration? = nil,
        additionalInfo: String? = nil,
        latestMeasurement: String? = nil,
        latestMeasurementDisplay: CardsSettingsAlertLatestMeasurement? = nil,
        headerSummaryText: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.noticeText = noticeText
        self.customDescriptionText = customDescriptionText
        self.limitDescription = limitDescription
        self.showsLimitEditIcon = showsLimitEditIcon
        self.sliderConfiguration = sliderConfiguration
        self.additionalInfo = additionalInfo
        self.latestMeasurement = latestMeasurement
        self.latestMeasurementDisplay = latestMeasurementDisplay ??
            CardsSettingsAlertLatestMeasurement(text: latestMeasurement)
        self.headerSummaryText = headerSummaryText
    }

    let isEnabled: Bool
    let noticeText: String?
    let customDescriptionText: String?
    let limitDescription: CardsSettingsAlertLimitDescription?
    let showsLimitEditIcon: Bool
    var sliderConfiguration: CardsSettingsAlertSliderConfiguration?
    let additionalInfo: String?
    let latestMeasurement: String?
    let latestMeasurementDisplay: CardsSettingsAlertLatestMeasurement?
    let headerSummaryText: String?
}

struct CardsSettingsAlertSliderConfiguration: Equatable {
    let range: ClosedRange<Double>
    let selectedRange: ClosedRange<Double>
    let unit: String
    let format: String
    let step: Double
    let minDistance: Double
    let lineHeight: Double
    let handleDiameter: Double
    let enableStep: Bool
    let hideLabels: Bool

    init(
        range: ClosedRange<Double>,
        selectedRange: ClosedRange<Double>,
        unit: String,
        format: String,
        step: Double = 1,
        minDistance: Double = 1,
        lineHeight: Double = 3,
        handleDiameter: Double = 18,
        enableStep: Bool = true,
        hideLabels: Bool = true
    ) {
        self.range = range
        self.selectedRange = selectedRange
        self.unit = unit
        self.format = format
        self.step = step
        self.minDistance = minDistance
        self.lineHeight = lineHeight
        self.handleDiameter = handleDiameter
        self.enableStep = enableStep
        self.hideLabels = hideLabels
    }

    var selectedRangeSummary: String {
        let lower = formattedValue(selectedRange.lowerBound)
        let upper = formattedValue(selectedRange.upperBound)
        if unit.isEmpty {
            return "\(lower) - \(upper)"
        }
        return "\(lower) - \(upper) \(unit)"
    }

    var selectedBoundsSummary: String {
        "\(selectedLowerDisplay) | \(selectedUpperDisplay)"
    }

    var selectedLowerDisplay: String {
        displayValue(selectedRange.lowerBound)
    }

    var selectedUpperDisplay: String {
        displayValue(selectedRange.upperBound)
    }

    var rangeLowerDisplay: String {
        displayValue(range.lowerBound)
    }

    var rangeUpperDisplay: String {
        displayValue(range.upperBound)
    }

    func withSelectedRange(
        _ newRange: ClosedRange<Double>
    ) -> CardsSettingsAlertSliderConfiguration {
        CardsSettingsAlertSliderConfiguration(
            range: range,
            selectedRange: newRange,
            unit: unit,
            format: format,
            step: step,
            minDistance: minDistance,
            lineHeight: lineHeight,
            handleDiameter: handleDiameter,
            enableStep: enableStep,
            hideLabels: hideLabels
        )
    }

    private func formattedValue(_ value: Double) -> String {
        String(format: format, value)
    }

    private func displayValue(_ value: Double) -> String {
        let base = formattedValue(value)
        return unit.isEmpty ? base : "\(base) \(unit)"
    }
}
