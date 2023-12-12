import Foundation
import RuuviLocal
import RuuviOntology

extension [AnyRuuviTagSensor] {
    func reordered() -> Self {
        sorted(by: {
            // Sort sensors by name alphabetically
            let first = $0.name.lowercased()
            let second = $1.name.lowercased()
            return first < second
        })
    }
}
