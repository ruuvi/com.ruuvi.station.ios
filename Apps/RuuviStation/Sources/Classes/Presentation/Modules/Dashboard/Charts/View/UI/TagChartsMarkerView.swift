import DGCharts
import RuuviLocalization
import RuuviService
import UIKit
import RuuviOntology

class TagChartsMarkerView: MarkerImage {
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

    init(
        color: UIColor? = RuuviColor.graphMarkerColor.color,
        font: UIFont = UIFont.Muli(.regular, size: 8),
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

        let distanceFromTop = point.y - rectangle.height
        let distanceFromBottom = point.y + rectangle.height

        if distanceFromTop <= 0 {
            // near top → shift marker down
            rectangle.origin.y = rectangle.height / 2
        } else if distanceFromBottom >= (parentFrame.height - yBottomPadding) {
            // near bottom → shift marker up
            rectangle.origin.y -= (rectangle.height + yBottomPadding)
        } else {
            // otherwise → standard “center vertically” offset
            rectangle.origin.y -= rectangle.height / 2 + yBottomPadding
        }

        if rectangle.minX < 0 {
            rectangle.origin.x = 0
        } else if rectangle.maxX > chartWidth {
            rectangle.origin.x = chartWidth - rectangle.width
        }

        // parentFrame is the chart area or superview bounds you want to respect.
        let maxY = parentFrame.height
        if rectangle.minY < 0 {
            rectangle.origin.y = 0
        } else if rectangle.maxY > maxY {
            rectangle.origin.y = maxY - rectangle.height
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
        let value = GlobalHelpers().formattedString(from: entry.y.round(to: 2))
        labelText = value + " " + unit
            + "\n" +
            AppDateFormatter.shared.graphMarkerDateString(from: entry.x)
    }
}

extension TagChartsMarkerView {
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
