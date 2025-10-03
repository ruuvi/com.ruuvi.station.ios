import DGCharts
import UIKit

class AQIYAxisRenderer: YAxisRenderer {
    private let steps: [Double] = [10, 50, 80, 90, 100]

    override func computeAxisValues(min: Double, max: Double) {
        axis.entries = steps
    }

    override func renderAxisLabels(context: CGContext) {
        guard axis.isEnabled, axis.isDrawLabelsEnabled else { return }

        let labelFont = axis.labelFont
        let labelTextColor = axis.labelTextColor
        let xOffset = axis.xOffset

        let positions = transformedPositions()

        for (i, step) in steps.enumerated() {
            let text = axis.valueFormatter?.stringForValue(step, axis: axis)
                ?? "\(Int(step))"

            let pt = positions[i]
            if viewPortHandler.isInBoundsY(pt.y) {
                drawYLabel(
                    context: context,
                    text: text,
                    x: viewPortHandler.contentLeft - xOffset,
                    y: pt.y,
                    attributes: [
                        .font: labelFont,
                        .foregroundColor: labelTextColor,
                    ],
                    anchor: CGPoint(x: 1.0, y: 0.5)
                )
            }
        }
    }

    override func transformedPositions() -> [CGPoint] {
        var positions = [CGPoint]()
        for step in steps {
            positions.append(CGPoint(x: 0, y: step))
        }
        transformer?.pointValuesToPixel(&positions)
        return positions
    }

    // MARK: - Private
    // swiftlint:disable:next function_parameter_count
    private func drawYLabel(
        context: CGContext,
        text: String,
        x: CGFloat,
        y: CGFloat,
        attributes: [NSAttributedString.Key: Any],
        anchor: CGPoint
    ) {
        let labelSize = text.size(withAttributes: attributes)
        let drawPoint = CGPoint(
            x: x - labelSize.width * anchor.x,
            y: y - labelSize.height * anchor.y
        )
        text.draw(at: drawPoint, withAttributes: attributes)
    }
}
