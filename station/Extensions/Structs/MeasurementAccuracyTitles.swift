import Foundation
import RuuviOntology
import RuuviLocal

struct MeasurementAccuracyTitles {
    func formattedTitle(type: MeasurementAccuracyType,
                        settings: RuuviLocalSettings) -> String {
        let formatter = NumberFormatter()
        formatter.locale = settings.language.locale
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: type.displayValue)) ?? "-"
    }
}
