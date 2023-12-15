import Charts
import RuuviLocalization
import RuuviService
import UIKit

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
        guard let attrs
        else {
            return
        }
        // Padding for the label.
        let labelWidth = labelText.size(withAttributes: attrs).width + hPadding
        let labelHeight = labelText.size(withAttributes: attrs).height + vPadding

        // Set position of the marker view container
        var rectangle = CGRect(
            x: point.x,
            y: point.y,
            width: labelWidth,
            height: labelHeight
        )
        let screenSize: CGRect = UIScreen.main.bounds
        if (point.x + rectangle.width) >= screenSize.width {
            rectangle.origin.x -= rectangle.width
        } else {
            rectangle.origin.x -= rectangle.width / 2
        }

        let distanceFromTop = point.y - rectangle.height
        let distanceFromBottom = point.y + rectangle.height
        // Place the markup in correct Y position.
        // If the touch point and the markup height exceeds the minimum Y-position,
        // place to to minimum Y-position. And, otherwise for the maximum Y-position.
        // For rest of the cases place it near to the touch point.
        if distanceFromTop <= 0 {
            rectangle.origin.y = rectangle.height / 2
        } else if distanceFromBottom >= (parentFrame.height - yBottomPadding) {
            rectangle.origin.y -= (rectangle.height + yBottomPadding)
        } else {
            rectangle.origin.y -= rectangle.height / 2 + yBottomPadding
        }

        // Rounded corner
        let clipPath = UIBezierPath(
            roundedRect: rectangle,
            cornerRadius: cornerRadius
        ).cgPath
        context.addPath(clipPath)
        context.setFillColor(color.cgColor)
        context.setStrokeColor(UIColor.clear.cgColor)
        context.closePath()
        context.drawPath(using: .fillStroke)

        // Draw
        labelText.draw(
            with: rectangle,
            options: .usesLineFragmentOrigin,
            attributes: attrs,
            context: nil
        )
    }

    override func refreshContent(entry: ChartDataEntry, highlight _: Highlight) {
        var value = ""
        switch type {
        case .temperature:
            value = measurementService.stringWithoutSign(temperature: entry.y)
        case .humidity:
            value = measurementService.stringWithoutSign(humidity: entry.y)
        case .pressure:
            value = measurementService.stringWithoutSign(pressure: entry.y)
        default: break
        }

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
