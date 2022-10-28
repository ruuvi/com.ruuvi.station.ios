import Foundation
import Charts

public class YAxisValueFormatter: NSObject, AxisValueFormatter {
    private let numberFormatter = NumberFormatter()

    init(with locale: Locale) {
        numberFormatter.locale = locale
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 1
    }

    public func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        guard let value = numberFormatter.string(from: NSNumber(value: value)) else {
            return ""
        }
        return value
    }
}
