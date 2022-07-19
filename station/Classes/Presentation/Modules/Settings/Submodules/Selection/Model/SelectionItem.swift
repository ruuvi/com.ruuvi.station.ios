import Foundation
import RuuviOntology

protocol SelectionItemProtocol {
    var title: String { get }
}

struct SelectionViewModel {
    let title: String
    let items: [SelectionItemProtocol]
    let description: String
    let selection: String
    let measurementType: MeasurementType
    let unitSettingsType: UnitSettingsType
}
