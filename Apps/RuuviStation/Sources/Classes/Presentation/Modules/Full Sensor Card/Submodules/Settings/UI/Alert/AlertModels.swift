import Foundation

enum AlertLimitDescription: Equatable {
    case staticText(String)
    case sliderLocalized
}

struct AlertUIConfiguration: Equatable {
    let isEnabled: Bool
    let noticeText: String?
    let customDescriptionText: String?
    let limitDescription: AlertLimitDescription?
    let showsLimitEditIcon: Bool
    var sliderConfiguration: AlertSliderConfiguration?
    let additionalInfo: String?
    let latestMeasurement: String?
}

struct AlertSliderConfiguration: Equatable {
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

    func withSelectedRange(_ newRange: ClosedRange<Double>) -> AlertSliderConfiguration {
        AlertSliderConfiguration(
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
