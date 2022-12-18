import Foundation
import Charts
import RuuviOntology

public class DateValueFormatter: NSObject, AxisValueFormatter {
    private let locale: Locale?

    init(with locale: Locale) {
        self.locale = locale
    }

    public func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let date = Date(timeIntervalSince1970: value)
        return DateFormatter.localizedString(from: date,
                                             dateStyle: .none,
                                             timeStyle: .short)
        + "\n"
            + stringFromDate(from: date)
    }

    private func stringFromDate(from date: Date) -> String {
        if locale == Language.english.locale {
            return AppDateFormatter.shared.enLocaleDateString(from: date)
        } else {
            return AppDateFormatter.shared.nonEnLocaleDateString(from: date)
        }
    }
}
