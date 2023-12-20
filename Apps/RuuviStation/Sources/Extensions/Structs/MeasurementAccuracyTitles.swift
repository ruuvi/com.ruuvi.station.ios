import Foundation
import RuuviLocal
import RuuviOntology

struct MeasurementAccuracyTitles {
    func formattedTitle(
        type: MeasurementAccuracyType,
        settings _: RuuviLocalSettings
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: type.displayValue)) ?? "-"
    }
}
