import DGCharts
import Foundation
import RuuviOntology

public class XAxisValueFormatter: NSObject, AxisValueFormatter {
    var tickInterval: TimeInterval = 0
    var visibleRange: TimeInterval = 0

    public func stringForValue(_ value: Double, axis _: AxisBase?) -> String {
        let date = Date(timeIntervalSince1970: value)

        if visibleRange >= 365 * 86400 {
            return AppDateFormatter.shared.graphXAxisDateWithYearString(from: date)
        } else if tickInterval >= 86400 || date.isStartOfTheDay() {
            return AppDateFormatter.shared.graphXAxisDateString(from: date)
        } else {
            return AppDateFormatter.shared.graphXAxisTimeString(from: date)
        }
    }
}
