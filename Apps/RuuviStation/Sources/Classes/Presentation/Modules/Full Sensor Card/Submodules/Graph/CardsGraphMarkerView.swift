import DGCharts
import RuuviLocalization
import RuuviService
import UIKit
import RuuviOntology

class CardsGraphMarkerView: MarkerImage {
    private(set) var color: UIColor
    private(set) var font: UIFont
    private(set) var textColor: UIColor

    private var labelText: String = ""
    private var attrs: [NSAttributedString.Key: AnyObject]!
    private var unit: String = ""
    private var type: MeasurementType = .temperature
    private var measurementService: RuuviServiceMeasurement!
    private var parentFrame: CGRect = .zero

    private let baselineOffset: Int = -4
    private let hPadding: CGFloat = 10.0
    private let vPadding: CGFloat = 4.0
    private let cornerRadius: CGFloat = 4.0
    private let yBottomPadding: CGFloat = 32.0
    private let pointSpacing: CGFloat = 8.0

    init(
        color: UIColor? = RuuviColor.graphMarkerColor.color,
        font: UIFont = UIFont.ruuviCaption2(),
        textColor: UIColor = .white
    ) {
        if let color {
            self.color = color
        } else {
            self.color = .darkGray
        }

        self.font = font
        self.textColor = textColor

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        attrs = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: textColor,
            .baselineOffset: NSNumber(value: baselineOffset),
        ]
        super.init()
    }

    override func draw(context: CGContext, point: CGPoint) {
        guard let attrs else { return }

        let labelWidth = labelText.size(withAttributes: attrs).width + hPadding
        let labelHeight = labelText.size(withAttributes: attrs).height + vPadding
        var rectangle = CGRect(x: point.x, y: point.y, width: labelWidth, height: labelHeight)

        let chartWidth = chartView?.bounds.width ?? UIScreen.main.bounds.width
        if (point.x + rectangle.width) >= chartWidth {
            // shift left
            rectangle.origin.x -= rectangle.width
        } else {
            // center horizontally
            rectangle.origin.x -= rectangle.width / 2
        }

        let maxY = max(0, parentFrame.height - yBottomPadding)
        let minY: CGFloat = 0
        let aboveY = point.y - pointSpacing - rectangle.height
        let belowY = point.y + pointSpacing
        let canFitAbove = aboveY >= minY
        let canFitBelow = (belowY + rectangle.height) <= maxY

        if canFitAbove {
            rectangle.origin.y = aboveY
        } else if canFitBelow {
            rectangle.origin.y = belowY
        } else {
            let aboveOverflow = minY - aboveY
            let belowOverflow = (belowY + rectangle.height) - maxY
            rectangle.origin.y = aboveOverflow <= belowOverflow ? aboveY : belowY
        }

        if rectangle.minX < 0 {
            rectangle.origin.x = 0
        } else if rectangle.maxX > chartWidth {
            rectangle.origin.x = chartWidth - rectangle.width
        }

        if canFitAbove || canFitBelow {
            if rectangle.minY < minY {
                rectangle.origin.y = minY
            } else if rectangle.maxY > maxY {
                rectangle.origin.y = maxY - rectangle.height
            }
        }

        // Draw the background rectangle (rounded corners).
        let clipPath = UIBezierPath(roundedRect: rectangle, cornerRadius: cornerRadius).cgPath
        context.addPath(clipPath)
        context.setFillColor(color.cgColor)
        context.fillPath()

        // Draw text
        labelText.draw(
            with: rectangle,
            options: .usesLineFragmentOrigin,
            attributes: attrs,
            context: nil
        )

        lastDrawnRect = rectangle
    }

    override func refreshContent(entry: ChartDataEntry, highlight _: Highlight) {
        let roundTo = type == .aqi ? 1 : 2
        let value = GlobalHelpers().formattedString(
            from: entry.y,
            minPlace: 0,
            toPlace: roundTo
        )
        labelText = value + " " + unit
            + "\n" +
            AppDateFormatter.shared.graphMarkerDateString(from: entry.x)
    }
}

extension CardsGraphMarkerView {
    func initialise(
        with unit: String,
        type: MeasurementType,
        measurementService: RuuviServiceMeasurement,
        parentFrame: CGRect
    ) {
        self.unit = unit
        self.type = type
        self.measurementService = measurementService
        self.parentFrame = parentFrame
    }
}
