import Foundation
import RuuviOntology

extension MeasurementAccuracyType: SelectionItemProtocol {
    public var title: String {
        switch self {
        case .zero:
            return "1"
        case .one:
            return "0.1"
        case .two:
            return "0.01"
        }
    }
}
