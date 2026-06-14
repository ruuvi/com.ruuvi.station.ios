import Foundation
import RuuviOntology

protocol SelectionItemProtocol {
    var title: (String) -> String { get }
}

struct SelectionViewModel {
    let title: String
    let items: [SelectionItemProtocol]
    let description: String
    let selection: String
    let measurementType: MeasurementType
    let unitSettingsType: UnitSettingsType
    let resolutionTarget: ResolutionSettingsTarget?

    init(
        title: String,
        items: [SelectionItemProtocol],
        description: String,
        selection: String,
        measurementType: MeasurementType,
        unitSettingsType: UnitSettingsType,
        resolutionTarget: ResolutionSettingsTarget? = nil
    ) {
        self.title = title
        self.items = items
        self.description = description
        self.selection = selection
        self.measurementType = measurementType
        self.unitSettingsType = unitSettingsType
        self.resolutionTarget = resolutionTarget
    }
}
