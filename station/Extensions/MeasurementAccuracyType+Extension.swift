import Foundation
import RuuviOntology

extension MeasurementAccuracyType: SelectionItemProtocol {
    public var title: (String) -> String {
        switch self {
        case .zero: { _ in "1" }
        case .one: { _ in "0.1" }
        case .two: { _ in "0.01" }
        }
    }
}
