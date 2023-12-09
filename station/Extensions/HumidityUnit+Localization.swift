import Foundation
import RuuviLocalization
import RuuviOntology

extension HumidityUnit: SelectionItemProtocol {
    var title: (String) -> String {
        switch self {
        case .percent: { _ in RuuviLocalization.HumidityUnit.Percent.title }
        case .gm3: { _ in RuuviLocalization.HumidityUnit.Gm3.title }
        case .dew:
            RuuviLocalization.HumidityUnit.Dew.title
        }
    }

    var symbol: String {
        switch self {
        case .percent:
            "%"
        case .gm3:
            RuuviLocalization.gm³
        case .dew:
            "°"
        }
    }

    var alertRange: Range<Double> {
        switch self {
        case .gm3:
            .init(uncheckedBounds: (lower: 0, upper: 40))
        case .percent:
            .init(uncheckedBounds: (lower: 0, upper: 100))
        case .dew:
            .init(uncheckedBounds: (lower: 0, upper: 100))
        }
    }
}
