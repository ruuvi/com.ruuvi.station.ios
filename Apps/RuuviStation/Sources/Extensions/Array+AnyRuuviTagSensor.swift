import Foundation
import RuuviLocal
import RuuviOntology

extension [AnyRuuviTagSensor] {
    func reordered(useImprovedAlphabeticalSorting: Bool) -> Self {
        sorted(by: {
            // Sort sensors by name alphabetically
            if useImprovedAlphabeticalSorting {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            } else {
                let first = $0.name.lowercased()
                let second = $1.name.lowercased()
                return first < second
            }
        })
    }
}
