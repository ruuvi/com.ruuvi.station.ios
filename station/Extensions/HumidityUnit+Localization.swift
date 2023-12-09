import Foundation
import RuuviOntology
import RuuviLocalization

extension HumidityUnit: SelectionItemProtocol {
    var title: (String) -> String {
        switch self {
        case .percent:
            return { _ in RuuviLocalization.HumidityUnit.Percent.title }
        case .gm3:
            return { _ in RuuviLocalization.HumidityUnit.Gm3.title }
        case .dew:
            return RuuviLocalization.HumidityUnit.Dew.title
        }
    }

    var symbol: String {
        switch self {
        case .percent:
            return "%"
        case .gm3:
            return RuuviLocalization.gm³
        default:
            return "°" // TODO: @rinat localize
        }
    }

    var alertRange: Range<Double> {
        switch self {
        case .gm3:
            return .init(uncheckedBounds: (lower: 0, upper: 40))
        case .percent:
            return .init(uncheckedBounds: (lower: 0, upper: 100))
        case .dew:
            return .init(uncheckedBounds: (lower: 0, upper: 100))
        }
    }
}
