import Foundation
import RuuviOntology
import RuuviLocal

extension Array where Element == AnyRuuviTagSensor {
    func reordered(by settings: RuuviLocalSettings) -> Self {
        var settings = settings
        if settings.tagsSorting.isEmpty {
            settings.tagsSorting = self.map({$0.id})
            return self
        } else {
            return self.reorder(by: settings.tagsSorting)
        }
    }
}
