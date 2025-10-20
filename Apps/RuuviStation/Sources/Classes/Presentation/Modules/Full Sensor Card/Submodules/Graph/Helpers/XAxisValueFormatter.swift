import DGCharts
import Foundation
import RuuviOntology

public class XAxisValueFormatter: NSObject, AxisValueFormatter {
    public func stringForValue(_ value: Double, axis _: AxisBase?) -> String {
        let date = Date(timeIntervalSince1970: value)

        if date.isStartOfTheDay() {
            return AppDateFormatter.shared.graphXAxisDateString(from: date)
        } else {
            return AppDateFormatter.shared.graphXAxisTimeString(from: date)
        }
    }
}
