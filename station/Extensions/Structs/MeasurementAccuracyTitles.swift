import Foundation
import RuuviOntology
import RuuviLocal

struct MeasurementAccuracyTitles {
    func formattedTitle(type: MeasurementAccuracyType,
                        settings: RuuviLocalSettings) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: type.displayValue)) ?? "-"
    }
}
