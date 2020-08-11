import Foundation
import Charts

public class DateValueFormatter: NSObject, IAxisValueFormatter {
    private let dateFormatter = DateFormatter()

    override init() {
        super.init()
        dateFormatter.dateFormat = "dd/MM"
    }

    public func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let date = Date(timeIntervalSince1970: value)
        return DateFormatter.localizedString(from: date,
                                             dateStyle: .none,
                                             timeStyle: .short)
        + "\n"
            + dateFormatter.string(from: date)
    }
}
