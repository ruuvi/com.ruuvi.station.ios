import Foundation
import RuuviOntology

extension [AnyRuuviTagSensor] {
    func reordered() -> Self {
        sorted(by: {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        })
    }
}
