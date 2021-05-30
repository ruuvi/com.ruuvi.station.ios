import Foundation
import Charts
import RuuviOntology

public class DateValueFormatter: NSObject, IAxisValueFormatter {
    private let dateFormatter = DateFormatter()

    init(with locale: Locale) {
        if locale == Language.english.locale {
            dateFormatter.dateFormat = "MM/dd"
        } else {
            dateFormatter.dateFormat = "dd/MM"
        }
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
