import Foundation
import RuuviOntology
import RuuviLocal

extension Array where Element == AnyRuuviTagSensor {
    func reordered() -> Self {
        return self.sorted(by: {
            // Sort sensors by name alphabetically
            let first = $0.name.lowercased()
            let second = $1.name.lowercased()
            return first < second
        })
    }
}
