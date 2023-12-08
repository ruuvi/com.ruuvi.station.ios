import Foundation
import RuuviOntology

extension MeasurementAccuracyType: SelectionItemProtocol {
    public var title: (String) -> String {
        switch self {
        case .zero:
            return { _ in "1" }
        case .one:
            return { _ in "0.1" }
        case .two:
            return { _ in "0.01" }
        }
    }
}
