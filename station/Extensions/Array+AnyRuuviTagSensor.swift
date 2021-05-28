import Foundation
import RuuviOntology

extension Array where Element == AnyRuuviTagSensor {
    func reordered(by settings: Settings) -> Self {
        var settings = settings
        if settings.tagsSorting.isEmpty {
            settings.tagsSorting = self.map({$0.id})
            return self
        } else {
            return self.reorder(by: settings.tagsSorting)
        }
    }
}
