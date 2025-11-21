import SwiftUI
import UIKit
import RangeSeekSlider
import RuuviLocalization

struct CardsSettingsAlertRangeSliderView: View {
    let configuration: CardsSettingsAlertSliderConfiguration
    let onRangeChange: (Double, Double) -> Void
    let onRangeChangeEnd: (Double, Double) -> Void

    private struct Constants {
        static let sliderHeight: CGFloat = 40
    }

    var body: some View {
        RangeSeekSliderRepresentable(
            configuration: configuration,
            onRangeChange: onRangeChange,
            onRangeChangeEnd: onRangeChangeEnd
        )
        .frame(height: Constants.sliderHeight)
    }
}

private struct RangeSeekSliderRepresentable: UIViewRepresentable {
    let configuration: CardsSettingsAlertSliderConfiguration
    let onRangeChange: (Double, Double) -> Void
    let onRangeChangeEnd: (Double, Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onRangeChange: onRangeChange,
            onRangeChangeEnd: onRangeChangeEnd
        )
    }

    func makeUIView(context: Context) -> RURangeSeekSlider {
        let slider = RURangeSeekSlider()
        slider.isUserInteractionEnabled = true
        slider.delegate = context.coordinator
        applyConfiguration(configuration, to: slider)
        return slider
    }

    func updateUIView(_ slider: RURangeSeekSlider, context: Context) {
        if slider.delegate !== context.coordinator {
            slider.delegate = context.coordinator
        }
        context.coordinator.onRangeChange = onRangeChange
        context.coordinator.onRangeChangeEnd = onRangeChangeEnd
        applyConfiguration(configuration, to: slider)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func applyConfiguration(
        _ configuration: CardsSettingsAlertSliderConfiguration,
        to slider: RURangeSeekSlider
    ) {
        var needsRefresh = false

        let minValue = CGFloat(configuration.range.lowerBound)
        if slider.minValue != minValue {
            slider.minValue = minValue
            needsRefresh = true
        }

        let maxValue = CGFloat(configuration.range.upperBound)
        if slider.maxValue != maxValue {
            slider.maxValue = maxValue
            needsRefresh = true
        }

        let selectedMin = CGFloat(configuration.selectedRange.lowerBound)
        if slider.selectedMinValue != selectedMin {
            slider.selectedMinValue = selectedMin
            needsRefresh = true
        }

        let selectedMax = CGFloat(configuration.selectedRange.upperBound)
        if slider.selectedMaxValue != selectedMax {
            slider.selectedMaxValue = selectedMax
            needsRefresh = true
        }

        let step = CGFloat(configuration.step)
        if slider.step != step {
            slider.step = step
        }

        if slider.enableStep != configuration.enableStep {
            slider.enableStep = configuration.enableStep
        }

        let minDistance = CGFloat(configuration.minDistance)
        if slider.minDistance != minDistance {
            slider.minDistance = minDistance
        }

        let lineHeight = CGFloat(configuration.lineHeight)
        if slider.lineHeight != lineHeight {
            slider.lineHeight = lineHeight
            needsRefresh = true
        }

        let handleDiameter = CGFloat(configuration.handleDiameter)
        if slider.handleDiameter != handleDiameter {
            slider.handleDiameter = handleDiameter
            needsRefresh = true
        }

        if slider.hideLabels != configuration.hideLabels {
            slider.hideLabels = configuration.hideLabels
        }

        if slider.backgroundColor != .clear {
            slider.backgroundColor = .clear
        }

        let highlightColor = RuuviColor.tintColor.color
        if slider.colorBetweenHandles != highlightColor {
            slider.colorBetweenHandles = highlightColor
        }

        if slider.handleColor != highlightColor {
            slider.handleColor = highlightColor
        }

        let trackColor = RuuviColor.graphAlertColor.color
        if slider.tintColor != trackColor {
            slider.tintColor = trackColor
        }

        if needsRefresh {
            slider.refresh()
        }
    }

    final class Coordinator: NSObject, RangeSeekSliderDelegate {
        var onRangeChange: (Double, Double) -> Void
        var onRangeChangeEnd: (Double, Double) -> Void

        init(
            onRangeChange: @escaping (Double, Double) -> Void,
            onRangeChangeEnd: @escaping (Double, Double) -> Void
        ) {
            self.onRangeChange = onRangeChange
            self.onRangeChangeEnd = onRangeChangeEnd
        }

        func rangeSeekSlider(
            _ slider: RangeSeekSlider,
            didChange minValue: CGFloat,
            maxValue: CGFloat
        ) {
            onRangeChange(Double(minValue), Double(maxValue))
        }

        func didEndTouches(in slider: RangeSeekSlider) {
            onRangeChangeEnd(
                Double(slider.selectedMinValue),
                Double(slider.selectedMaxValue)
            )
        }
    }
}
